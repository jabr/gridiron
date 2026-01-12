# Gridiron workerd Configuration Template
# Simple path-based router - each service is independent

using Workerd = import "/workerd/workerd.capnp";

const config :Workerd.Config = (
  services = [
    # User services (dynamically generated) - each with its own path
    {{SERVICES}},
    
    # Path router - routes based on URL path to appropriate service
    (
      name = "router",
      worker = (
        modules = [(name = "router.js", esModule = embed "router.js")],
        compatibilityDate = "2026-02-14",
        compatibilityFlags = ["nodejs_compat", "nodejs_compat_populate_process_env"],
        bindings = [
          # Service bindings to all deployed workers (dynamically generated)
          {{SERVICE_BINDINGS}}
        ]
      )
    )
  ],

  sockets = [
    # Listen on TCP for service discovery and invocations
    (
      name = "http",
      address = "0.0.0.0:9080",
      http = (),
      service = "router"
    )
  ]
);

# User service worker definitions (dynamically generated)
{{WORKER_DEFINITIONS}}
