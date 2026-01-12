require "base64"
require "http/client"
require "json"
require "uri"
require "file_utils"
require "./models"
require "./state"
require "./restate_client"
require "./workerd_manager"

module Handlers
  extend self

  def health_check(context : HTTP::Server::Context)
    context.response.content_type = "text/plain"
    context.response.print("OK")
  end

  def activate_version(
    context : HTTP::Server::Context,
    state : State,
    restate_client : RestateClient,
    workerd_manager : WorkerdManager
  )
    begin
      body = context.request.body.try(&.gets_to_end) || "{}"
      request = Models::ActivateRequest.from_json(body)

      # Generate build ID with format: name-timestamp.ms-random
      # e.g., "greeter-1771295390.123-cfkv"
      now = Time.utc
      timestamp = now.to_unix
      ms = now.millisecond
      random_suffix = Random::Secure.hex(4)[0, 4]  # 4 char random hex
      build_id = "#{request.name}-#{timestamp}.#{ms}-#{random_suffix}"
      versioned_path = "/#{build_id}"

      Log.info { "Activating version: #{build_id} at path #{versioned_path}" }

      # Download/copy the bundle
      Log.info { "Downloading bundle from #{request.source}" }
      download_bundle_to_disk(request.source, state.get_bundle_path(build_id))

      # Check for WASM file (hashed filename pattern)
      has_wasm = !Dir.glob(File.join(state.get_bundle_path(build_id), "*-sdk_shared_core_wasm_bindings_bg.wasm")).empty?

      # Write metadata
      metadata = Models::BundleMetadata.new(
        name: request.name,
        version: request.version,
        timestamp: now,
        has_wasm: has_wasm
      )
      metadata_path = state.get_metadata_path(build_id)
      File.write(metadata_path, metadata.to_json)

      # Add to state
      deployment = Models::DeploymentInfo.new(build_id, metadata, versioned_path)
      state.add_deployment(deployment)

      # Generate new config with all deployments (includes new service)
      workerd_manager.generate_config(state.list_deployments)

      # Restart workerd to pick up new config
      # Workerd starts very fast, so downtime is minimal
      restart_success = workerd_manager.reload_workerd

      # Register with Restate via TCP at the specific service path
      # Each service is registered independently at http://localhost:9080/{build_id}
      # Restate calls GET /discover on that path
      begin
        tcp_uri = "http://localhost:9080/#{build_id}"
        deployment_id = restate_client.register_deployment(tcp_uri, use_http11: true)
        state.update_deployment_status(build_id, Models::DeploymentStatus::Active, deployment_id)
        Log.info { "Activated version: #{build_id} as deployment #{deployment_id}" }
        message = restart_success ? "Version activated and registered with Restate" : "Version activated but workerd restart pending"
      rescue ex
        Log.warn { "Could not register with Restate immediately: #{ex.message}" }
        deployment_id = nil
        message = "Registration with Restate failed. Error: #{ex.message}"
      end

      response = Models::ActivateResponse.new(
        build_id: build_id,
        deployment_id: deployment_id,
        path: versioned_path,
        message: message
      )

      context.response.content_type = "application/json"
      context.response.print(response.to_json)
    rescue ex
      Log.error { "Activation failed: #{ex.message}" }
      context.response.status_code = 500
      context.response.content_type = "application/json"
      context.response.print({error: ex.message}.to_json)
    end
  end

  def prune_version(
    context : HTTP::Server::Context,
    state : State,
    restate_client : RestateClient,
    workerd_manager : WorkerdManager
  )
    begin
      body = context.request.body.try(&.gets_to_end) || "{}"
      request = Models::PruneRequest.from_json(body)

      deployment = state.get_deployment(request.build_id)
      unless deployment
        context.response.status_code = 404
        context.response.content_type = "application/json"
        context.response.print({error: "Bundle not found: #{request.build_id}"}.to_json)
        return
      end

      # Unregister from Restate if we have a deployment ID
      if deployment_id = deployment.deployment_id || request.deployment_id
        restate_client.remove_deployment(deployment_id, force: true)
        Log.info { "Unregistered deployment #{deployment_id} from Restate" }
      end

      # Remove from state
      state.remove_deployment(request.build_id)

      # Remove bundle - disk dispatch will stop serving it immediately
      # No workerd restart needed
      workerd_manager.remove_bundle(request.build_id)

      Log.info { "Pruned version: #{request.build_id}" }

      response = Models::PruneResponse.new(
        build_id: request.build_id,
        message: "Version pruned successfully"
      )

      context.response.content_type = "application/json"
      context.response.print(response.to_json)
    rescue ex
      Log.error { "Pruning failed: #{ex.message}" }
      context.response.status_code = 500
      context.response.content_type = "application/json"
      context.response.print({error: ex.message}.to_json)
    end
  end

  def list_deployments(context : HTTP::Server::Context, state : State)
    deployments = state.list_deployments
    response = Models::ListDeploymentsResponse.new(deployments)

    context.response.content_type = "application/json"
    context.response.print(response.to_json)
  end

  def get_deployment_status(
    context : HTTP::Server::Context,
    state : State,
    restate_client : RestateClient,
    build_id : String
  )
    unless deployment = state.get_deployment(build_id)
      context.response.status_code = 404
      context.response.content_type = "application/json"
      context.response.print({error: "Bundle not found: #{build_id}"}.to_json)
      return
    end

    # If we have a deployment_id, fetch current status from Restate
    status = "unknown"
    active_invocations = 0_i64

    if deployment_id = deployment.deployment_id
      begin
        restate_dep = restate_client.get_deployment(deployment_id)
        active_invocations = restate_dep.active_invocations
        status = active_invocations == 0 ? "drained" : "active"
      rescue ex
        status = "error"
        Log.warn { "Failed to get deployment status from Restate: #{ex.message}" }
      end
    end

    response = {
      build_id: build_id,
      deployment_id: deployment.deployment_id,
      path: deployment.path,
      status: deployment.status.to_s.downcase,
      restate_status: status,
      active_invocations: active_invocations,
      activated_at: deployment.activated_at.try(&.to_rfc3339)
    }

    context.response.content_type = "application/json"
    context.response.print(response.to_json)
  end

  # Download/copy bundle from source URI to disk
  # Supports: file:// (MVP), https:// (future)
  # For Cloudflare Workers, expects a directory with index.js and optionally WASM
  private def download_bundle_to_disk(source : String, target_dir : String)
    uri = URI.parse(source)

    case uri.scheme
    when "file"
      # Local file or directory path
      source_path = uri.path || source.sub(/^file:\/\//, "")

      if File.directory?(source_path)
        # Copy entire directory (e.g., from wrangler output)
        FileUtils.mkdir_p(target_dir)
        Dir.each_child(source_path) do |entry|
          src = File.join(source_path, entry)
          dst = File.join(target_dir, entry)
          FileUtils.cp(src, dst)
        end
      elsif File.file?(source_path)
        # Single file - copy just the JS
        FileUtils.mkdir_p(target_dir)
        FileUtils.cp(source_path, File.join(target_dir, "index.js"))
      else
        raise "Source not found: #{source_path}"
      end
    when "https"
      raise "HTTPS download not yet implemented"
    else
      raise "Unsupported source scheme: #{uri.scheme}. Supported: file"
    end
  end
end
