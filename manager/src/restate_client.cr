require "http/client"
require "json"
require "./models"
require "./config"

class RestateClient
  @base_url : String

  def initialize(config : ManagerConfig)
    @base_url = config.restate_admin_url
  end

  def list_deployments : Array(Models::RestateDeployment)
    url = "#{@base_url}/deployments"
    response = HTTP::Client.get(url)

    if response.status_code == 200
      list = Models::RestateDeploymentList.from_json(response.body)
      list.deployments
    else
      raise "Failed to list deployments: #{response.status_code}"
    end
  end

  def register_deployment(uri : String, use_http11 : Bool = false) : String
    url = "#{@base_url}/v3/deployments"

    body = {
      "uri" => uri,
      "use_http_11" => true,
    }.to_json

    response = HTTP::Client.post(url, body: body, headers: HTTP::Headers{"Content-Type" => "application/json"})

    if response.status_code == 200 || response.status_code == 201
      result = JSON.parse(response.body)
      result["id"].as_s
    else
      raise "Failed to register deployment: #{response.status_code} - #{response.body}"
    end
  end

  def remove_deployment(deployment_id : String, force : Bool = false)
    url = "#{@base_url}/deployments/#{deployment_id}"
    url = "#{url}?force=true" if force

    response = HTTP::Client.delete(url)

    unless response.status_code == 200 || response.status_code == 204
      raise "Failed to remove deployment: #{response.status_code}"
    end
  end

  def get_deployment(deployment_id : String) : Models::RestateDeployment
    url = "#{@base_url}/deployments/#{deployment_id}"
    response = HTTP::Client.get(url)

    if response.status_code == 200
      Models::RestateDeployment.from_json(response.body)
    else
      raise "Failed to get deployment: #{response.status_code}"
    end
  end
end
