# Gridiron workerd Configuration
# Simple path-based router - each service is independent

using Workerd = import "/workerd/workerd.capnp";

const config :Workerd.Config = (
  services = [
    # Path router - routes based on URL path to appropriate service
    (
      name = "router",
      worker = (
        modules = [(name = "router.js", esModule = embed "router.js")],
        compatibilityDate = "2026-02-14",
        compatibilityFlags = ["nodejs_compat", "nodejs_compat_populate_process_env"],
        bindings = []
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
