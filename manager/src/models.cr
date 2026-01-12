require "json"
require "time"

module Models
  struct BundleMetadata
    include JSON::Serializable
    
    property name : String
    property version : String?  # Optional - not used in build_id anymore
    property timestamp : Time?
    property has_wasm : Bool  # Track if bundle includes WASM
    
    def initialize(@name : String, @version : String? = nil, @timestamp : Time? = nil, @has_wasm : Bool = false)
    end
  end
  
  # Request to activate a new version
  struct ActivateRequest
    include JSON::Serializable
    
    property source : String      # file://path or https://url
    property hash : String?       # sha256:abc123... (optional verification)
    property name : String        # Service name (e.g., "greeter")
    property version : String?    # Version (optional, not used in build_id)
    property wasm_source : String? # Optional WASM file source
  end
  
  struct ActivateResponse
    include JSON::Serializable
    
    property status : String
    property build_id : String
    property deployment_id : String?
    property path : String
    property message : String
    
    def initialize(@build_id : String, @deployment_id : String?, @path : String, @message : String)
      @status = "activated"
    end
  end
  
  # Request to prune/remove a version
  struct PruneRequest
    include JSON::Serializable
    
    property build_id : String
    property deployment_id : String?
  end
  
  struct PruneResponse
    include JSON::Serializable
    
    property status : String
    property build_id : String
    property message : String
    
    def initialize(@build_id : String, @message : String)
      @status = "pruned"
    end
  end
  
  enum DeploymentStatus
    Stored
    Active
    Draining
    Pruned
  end
  
  struct DeploymentInfo
    include JSON::Serializable
    
    property build_id : String
    property metadata : BundleMetadata
    property deployment_id : String?
    property status : DeploymentStatus
    property activated_at : Time?
    property path : String  # Versioned path like "/greeter/v1.0.0-123456"
    
    def initialize(@build_id : String, @metadata : BundleMetadata, @path : String)
      @deployment_id = nil
      @status = DeploymentStatus::Stored
      @activated_at = nil
    end
  end
  
  struct ListDeploymentsResponse
    include JSON::Serializable
    
    property deployments : Array(DeploymentInfo)
    
    def initialize(@deployments : Array(DeploymentInfo))
    end
  end
  
  struct RestateDeployment
    include JSON::Serializable
    
    property id : String
    property uri : String
    @[JSON::Field(key: "active_invocations")]
    property active_invocations : Int64
    @[JSON::Field(key: "created_at")]
    property created_at : String
  end
  
  struct RestateDeploymentList
    include JSON::Serializable
    
    property deployments : Array(RestateDeployment)
  end
end
