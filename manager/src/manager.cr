require "http/server"
require "json"
require "file_utils"
require "log"

require "./config"
require "./state"
require "./handlers"
require "./restate_client"
require "./workerd_manager"

# Setup logging
Log.setup_from_env

# Load configuration
config = ManagerConfig.from_env
Log.info { "Starting manager service..." }
Log.info { "Configuration: #{config.inspect}" }

# Initialize state
state = State.new(config)

# Initialize clients
restate_client = RestateClient.new(config)
workerd_manager = WorkerdManager.new(config)

# Create HTTP server
server = HTTP::Server.new do |context|
  request = context.request
  response = context.response
  
  # Log request
  Log.debug { "#{request.method} #{request.path}" }
  
  # Route request
  case {request.method, request.path}
  when {"GET", "/health"}
    Handlers.health_check(context)
  when {"POST", "/activate"}
    Handlers.activate_version(context, state, restate_client, workerd_manager)
  when {"POST", "/prune"}
    Handlers.prune_version(context, state, restate_client, workerd_manager)
  when {"GET", "/deployments"}
    Handlers.list_deployments(context, state)
  else
    if request.method == "GET" && request.path.starts_with?("/deployments/")
      build_id = request.path.split("/")[2]
      Handlers.get_deployment_status(context, state, restate_client, build_id)
    else
      response.status_code = 404
      response.content_type = "application/json"
      response.print({error: "Not found"}.to_json)
    end
  end
rescue ex
  Log.error { "Request failed: #{ex.message}" }
  context.response.status_code = 500
  context.response.content_type = "application/json"
  context.response.print({error: ex.message}.to_json)
end

# Start pruning subsystem in background
spawn do
  loop do
    begin
      Log.debug { "Running pruning check..." }
      # TODO: Implement pruning logic
      sleep 30.seconds
    rescue ex
      Log.error { "Pruning check failed: #{ex.message}" }
      sleep 30.seconds
    end
  end
end

# Start server
address = "0.0.0.0"
port = config.http_port
Log.info { "Manager listening on #{address}:#{port}" }

server.bind_tcp(address, port)
server.listen
