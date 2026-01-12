require "json"
require "file_utils"
require "log"
require "./models"
require "./config"

class State
  property config : ManagerConfig
  property deployments : Hash(String, Models::DeploymentInfo)
  
  def initialize(@config : ManagerConfig)
    @deployments = {} of String => Models::DeploymentInfo
    FileUtils.mkdir_p(@config.bundles_dir)
    FileUtils.mkdir_p(@config.state_dir)
    load_state
  end
  
  # Load state from disk
  def load_state
    state_file = @config.state_file_path
    if File.exists?(state_file)
      begin
        content = File.read(state_file)
        data = JSON.parse(content)
        
        if deployments_data = data["deployments"]?
          deployments_data.as_a.each do |dep_data|
            deployment = Models::DeploymentInfo.from_json(dep_data.to_json)
            @deployments[deployment.build_id] = deployment
          end
        end
        
        Log.info { "Loaded #{@deployments.size} deployments from state file" }
      rescue ex
        Log.error { "Failed to load state: #{ex.message}" }
      end
    end
    
    # Also scan bundles directory for any not in state
    load_existing_bundles
  end
  
  # Scan bundles directory and add any not already tracked
  def load_existing_bundles
    Dir.each_child(@config.bundles_dir) do |entry|
      next if @deployments.has_key?(entry)
      
      path = File.join(@config.bundles_dir, entry)
      next unless File.directory?(path)
      
      metadata_path = File.join(path, "metadata.json")
      if File.exists?(metadata_path)
        begin
          content = File.read(metadata_path)
          metadata = Models::BundleMetadata.from_json(content)
          # Generate path from name and version
          path = "/#{metadata.name}/#{metadata.version}-#{metadata.timestamp.try(&.to_unix) || 0}"
          deployment = Models::DeploymentInfo.new(entry, metadata, path)
          @deployments[entry] = deployment
          Log.info { "Found existing bundle: #{entry} at #{path}" }
        rescue ex
          Log.warn { "Failed to read metadata for #{entry}: #{ex.message}" }
        end
      end
    end
  end
  
  # Persist state to disk
  def save_state
    data = {
      "deployments" => @deployments.values.map { |d| JSON.parse(d.to_json) }
    }
    
    File.write(@config.state_file_path, data.to_json)
    Log.debug { "State saved to #{@config.state_file_path}" }
  rescue ex
    Log.error { "Failed to save state: #{ex.message}" }
  end
  
  def get_deployment(build_id : String) : Models::DeploymentInfo?
    @deployments[build_id]?
  end
  
  def add_deployment(deployment : Models::DeploymentInfo)
    @deployments[deployment.build_id] = deployment
    save_state
  end
  
  def remove_deployment(build_id : String)
    @deployments.delete(build_id)
    save_state
  end
  
  def list_deployments : Array(Models::DeploymentInfo)
    @deployments.values
  end
  
  def update_deployment_status(build_id : String, status : Models::DeploymentStatus, deployment_id : String? = nil)
    if deployment = @deployments[build_id]?
      deployment.status = status
      deployment.deployment_id = deployment_id if deployment_id
      deployment.activated_at = Time.utc if status == Models::DeploymentStatus::Active
      save_state
    end
  end
  
  def get_bundle_path(build_id : String) : String
    File.join(@config.bundles_dir, build_id)
  end
  
  def get_code_path(build_id : String) : String
    File.join(get_bundle_path(build_id), "index.js")
  end
  
  def get_metadata_path(build_id : String) : String
    File.join(get_bundle_path(build_id), "metadata.json")
  end
end
