require "json"

class ManagerConfig
  include JSON::Serializable
  
  property http_port : Int32
  property bundles_dir : String
  property state_dir : String
  property workerd_config_path : String
  property workerd_template_path : String
  property workerd_pid_file : String
  property restate_admin_url : String
  property socket_path : String
  
  def initialize(
    @http_port : Int32,
    @bundles_dir : String,
    @state_dir : String,
    @workerd_config_path : String,
    @workerd_template_path : String,
    @workerd_pid_file : String,
    @restate_admin_url : String,
    @socket_path : String
  )
  end
  
  def self.from_env : ManagerConfig
    new(
      http_port: ENV.fetch("MANAGER_PORT", "8081").to_i,
      bundles_dir: ENV.fetch("BUNDLES_DIR", "/data/bundles"),
      state_dir: ENV.fetch("MANAGER_STATE_DIR", "/data/manager"),
      workerd_config_path: ENV.fetch("WORKERD_CONFIG_PATH", "/opt/gridiron/config/workerd.capnp"),
      workerd_template_path: ENV.fetch("WORKERD_TEMPLATE_PATH", "/opt/gridiron/config/workerd-template.capnp"),
      workerd_pid_file: ENV.fetch("WORKERD_PID_FILE", "/run/workerd.pid"),
      restate_admin_url: ENV.fetch("RESTATE_ADMIN_URL", "http://localhost:9070"),
      socket_path: ENV.fetch("WORKERD_SOCKET_PATH", "/run/workerd.sock")
    )
  end
  
  def state_file_path : String
    File.join(@state_dir, "state.json")
  end
end
