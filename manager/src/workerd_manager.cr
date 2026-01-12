require "file_utils"
require "log"
require "./models"
require "./config"

class WorkerdManager
  @config : ManagerConfig

  def initialize(@config : ManagerConfig)
  end

  def generate_config(deployments : Array(Models::DeploymentInfo))
    return if deployments.empty?

    Log.info { "Generating workerd configuration with #{deployments.size} deployments..." }

    template = File.read(@config.workerd_template_path)

    services = [] of String
    worker_definitions = [] of String
    service_bindings = [] of String

    deployments.each do |deployment|
      # Use full build ID as the service identifier (e.g., "counter-1.0.0-1234")
      # This makes each deployment completely independent
      service_name = deployment.build_id
      camel_name = service_name.gsub(/[^a-zA-Z0-9]/, "_").split("_").map { |part| part.capitalize }.join
      bundle_dir = File.join(@config.bundles_dir, deployment.build_id)

      # Relative path to index.js from config dir
      code_path = "../../../data/bundles/#{deployment.build_id}/index.js"

      # Add service entry with unique name (use original build ID format)
      services << "(name = \"#{service_name}\", worker = .worker#{camel_name})"

      # Add service binding for router - binding name matches the path prefix
      # e.g., binding "counter-1.0.0-1234" points to service "counter-1.0.0-1234"
      service_bindings << "(name = \"#{service_name}\", service = \"#{service_name}\")"

      # Build worker definition
      if deployment.metadata.has_wasm
        wasm_files = Dir.glob(File.join(bundle_dir, "*-sdk_shared_core_wasm_bindings_bg.wasm"))
        wasm_filename = wasm_files.empty? ? "sdk_shared_core_wasm_bindings_bg.wasm" : File.basename(wasm_files.first)
        wasm_path = "../../../data/bundles/#{deployment.build_id}/#{wasm_filename}"

        worker_def = <<-WORKER
const worker#{camel_name} :Workerd.Worker = (
  modules = [
    (name = "worker.js", esModule = embed "#{code_path}"),
    (name = "#{wasm_filename}", wasm = embed "#{wasm_path}")
  ],
  compatibilityDate = "2026-02-14",
  compatibilityFlags = ["nodejs_compat", "nodejs_compat_populate_process_env"]
);
WORKER
      else
        worker_def = <<-WORKER
const worker#{camel_name} :Workerd.Worker = (
  modules = [(name = "worker.js", esModule = embed "#{code_path}")],
  compatibilityDate = "2026-02-14",
  compatibilityFlags = ["nodejs_compat", "nodejs_compat_populate_process_env"]
);
WORKER
      end
      worker_definitions << worker_def
    end

    # Replace placeholders in template
    services_text = services.join(",\n    ")

    config = template
      .gsub("{{SERVICES}}", services_text)
      .gsub("{{SERVICE_BINDINGS}}", service_bindings.join(",\n          "))
      .gsub("{{WORKER_DEFINITIONS}}", worker_definitions.join("\n\n"))

    File.write(@config.workerd_config_path, config)

    Log.info { "Workerd configuration generated at #{@config.workerd_config_path} with #{deployments.size} services" }
  end

  def deploy_bundle(deployment : Models::DeploymentInfo)
    Log.info { "Bundle #{deployment.build_id} ready at #{@config.bundles_dir}" }
    true
  end

  def remove_bundle(build_id : String)
    Log.info { "Bundle #{build_id} removal handled" }
    true
  end

  def reload_workerd
    # With --watch mode, workerd automatically reloads when config changes
    # Just log that the config has been updated
    Log.info { "Workerd config updated - workerd will auto-reload via --watch" }
    sleep 1
    true
  end

  def get_config_path : String
    @config.workerd_config_path
  end


end
