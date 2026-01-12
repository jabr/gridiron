# Gridiron - Agent Instructions

## Project Overview

Gridiron combines Restate.dev (durable execution orchestration) with workerd (Cloudflare Workers V8 isolate runtime) to create a general-purpose distributed compute mesh with hot code deployment capabilities.

**Key Components:**
- **Restate Server**: Durable execution orchestration (Rust binary)
- **workerd Runtime**: V8 isolate-based JavaScript/TypeScript/Wasm execution (C++ binary)
- **Manager**: Deployment management sidecar (Crystal, zero deps)
- **TCP Communication**: HTTP-based communication between components

## Architecture Decisions

### Path-Based Versioning

Gridiron uses **parallel deployments** with path-based routing instead of traditional hot reload:

```
Initial: workerd offers /demo/1.0.0-123 via HTTP, Restate routes to it
New Deploy: workerd now offers /demo/1.0.0-123 AND /demo/1.0.0-124
           Restate registers http://localhost:9080/demo/1.0.0-124
           New calls → /demo/1.0.0-124, in-flight calls → /demo/1.0.0-123
Drained: Restate reports 0 active on /demo/1.0.0-123
         Unregister, remove from config
         workerd offers: /demo/1.0.0-124
```

**Benefits:**
- Determinism: Restate replays execution logs against exact same code version
- Safety: Old version stays alive until all executions complete
- Zero Downtime: New version activates immediately
- Independent Lifecycles: Different service bundles update independently

### Manager Service (Crystal)

Implemented in **Crystal** (not TypeScript/JavaScript) for:
- Zero external dependencies (uses only Crystal stdlib)
- Native compiled binary (10-20MB, fast startup)
- Ruby-like concise syntax
- HTTP client/server built-in

**Responsibilities:**
1. Store code bundles (file:// support, s3:// planned)
2. Generate workerd Cap'n Proto config from templates
3. Reload workerd via runit restart
4. Register/unregister deployments with Restate Admin API
5. Monitor and prune old versions when drained
6. Track deployment state via JSON files

**API Endpoints:**
- `POST /activate` - Download bundle, store, generate config, reload workerd, register with Restate
- `POST /prune` - Unregister from Restate, remove files, regenerate config
- `GET /deployments` - List all deployments
- `GET /deployments/:build_id` - Get deployment status

### Communication Model

- **Restate → workerd**: HTTP/TCP for service invocations
- **Manager → Restate**: HTTP/TCP to Admin API (port 9070) for registration
- **Manager → workerd**: runit control for config reloads
- **workerd Discovery**: HTTP/TCP (port 9080) for Restate to discover services

### Pruning Strategy

Implemented as automatic subsystem in Crystal manager:
- Polls Restate Admin API every 30s for deployment status
- Checks active invocation counts
- Automatically removes drained deployments
- Background spawn, no worker coordination needed

### State Persistence

Uses **JSON files** (not SQLite) for zero dependencies:
```
/data/manager/
  state.json          # Deployment registry
/data/bundles/
  {name}-{version}-{timestamp}/
    index.js          # Bundle code (from wrangler build)
    metadata.json     # Bundle metadata
    sdk_shared_core_wasm_bindings_bg.wasm  # WASM for Restate SDK
```

State is rebuilt from filesystem on startup if JSON is missing/corrupt.

## Directory Structure

```
gridiron/
├── manager/                    # Manager service (Crystal)
│   ├── src/
│   │   ├── manager.cr         # Entry point
│   │   ├── config.cr          # Configuration
│   │   ├── state.cr           # State management
│   │   ├── handlers.cr        # HTTP handlers
│   │   ├── restate_client.cr  # Restate API client
│   │   ├── workerd_manager.cr # Workerd config management
│   │   └── models.cr          # Data models
│   ├── shard.yml              # Crystal dependencies (empty)
│   └── README.md
│
├── config/
│   ├── restate.toml           # Restate server config
│   ├── workerd-template.capnp # Template for config generation
│   └── workerd.capnp          # Generated runtime config (gitignore)
│
├── demo/                      # Example workers (TypeScript/Wrangler)
│   ├── counter/              # Counter service (virtual object)
│   │   ├── src/index.ts
│   │   ├── package.json
│   │   └── wrangler.toml
│   ├── greeter/              # Greeter service (stateless)
│   │   ├── src/index.ts
│   │   ├── package.json
│   │   └── wrangler.toml
│   └── GETTING_STARTED.md    # Demo walkthrough guide
│
├── runit/                     # Service supervision (runit)
│   ├── restate/run
│   ├── workerd/run
│   └── manager/run
│
├── scripts/                   # Utility scripts
│   ├── status.sh             # Check service status
│   └── gridiron-client.sh    # Call Restate services
│
├── Justfile                   # Build commands
└── AGENTS.md                  # This file
```

## Configuration

### Workerd Template (config/workerd-template.capnp)

```capnp
using Workerd = import "/workerd/workerd.capnp";

const config :Workerd.Config = (
  services = [
    {{SERVICES}}  # Dynamically generated per deployment
  ],
  sockets = [
    (name = "http", address = "0.0.0.0:9080", ...)  # For discovery and invocations
  ]
);

{{WORKER_DEFINITIONS}}  # Dynamically generated worker definitions
```

### Manager Environment Variables

```bash
MANAGER_PORT=8081                    # HTTP port
BUNDLES_DIR=/data/bundles            # Bundle storage
MANAGER_STATE_DIR=/data/manager      # State storage
WORKERD_CONFIG_PATH=/opt/gridiron/config/workerd.capnp
WORKERD_TEMPLATE_PATH=/opt/gridiron/config/workerd-template.capnp
RESTATE_ADMIN_URL=http://localhost:9070
```

### Port Allocation

- **5122**: Restate internal fabric (default)
- **9070**: Restate Admin API (default)
- **8080**: Restate user ingress (default)
- **8081**: Manager HTTP API
- **9080**: Workerd TCP (for Restate discovery)

## Build Commands (Justfile)

```bash
just build      # Build manager binary
just dev        # Development build (faster)
just run        # Run locally
just test       # Run tests
just fmt        # Format code
just clean      # Clean artifacts

just docker-build    # Build Docker image
just docker-run      # Run container
just docker-shell    # Interactive shell
just status          # Check all components
just deploy NAME VERSION FILE   # Deploy via Manager
just call SERVICE HANDLER ...   # Call Restate service
```

## Deployment Flow

1. **Manager invocation**: Call `POST /activate` with:
   ```json
   {
     "source": "file:///path/to/bundle/directory",
     "name": "greeter",
     "version": "1.0.0"
   }
   ```

2. **Manager actions**:
   - Copy bundle directory to `/data/bundles/{name}-{version}-{timestamp}/`
   - Write metadata.json
   - Generate workerd config from template
   - Request workerd restart via runit
   - Register with Restate: `POST /deployments` with URI `http://localhost:9080/{path}`

3. **Restate handles routing**:
   - New invocations → new version
   - In-flight invocations → old version until complete

4. **Pruning** (automatic or manual via `/prune`):
   - Manager polls Restate for active invocation counts
   - When count hits 0, removes deployment
   - Unregisters from Restate, removes files, regenerates config

## Key Design Principles

1. **Zero external dependencies** for manager (Crystal stdlib only)
2. **Filesystem-based state** (JSON files)
3. **HTTP/TCP for all communication**
4. **Path-based versioning** for deterministic execution
5. **Automatic pruning** without worker coordination

## Technology Stack

- **Restate**: Rust, durable execution engine
- **workerd**: C++, V8 isolate runtime
- **Manager**: Crystal, zero deps
- **Services**: TypeScript + Wrangler (Cloudflare Workers SDK)
- **Supervision**: runit (C-based)
- **Build**: Just (command runner)

## TODO / Project Status

### Completed
- ✅ Restate + workerd integration over HTTP/TCP
- ✅ Manager service in Crystal (zero deps)
- ✅ Path-based versioning for hot deployment
- ✅ Deployment and pruning APIs
- ✅ Automatic deployment pruning (polls Restate every 30s)
- ✅ Demo services (Counter, Greeter) with GETTING_STARTED guide
- ✅ Basic runit supervision

### In Progress / Partially Implemented
- 🚧 **Pruning reliability**: Auto-pruning exists but needs production testing under load
- 🚧 **Error handling**: Basic error handling in place, needs edge case coverage
- 🚧 **Bundle source types**: Only `file://` URLs supported, `s3://` and `https://` planned

### Limitations / Known Issues
- ⚠️ **Single node only**: No clustering or multi-node support yet
- ⚠️ **No persistence guarantees**: Manager state is JSON files; needs backup strategy
- ⚠️ **No auth**: Manager API is open, no authentication/authorization
- ⚠️ **workerd restart**: Full workerd restart on each deployment (could use workerd's HMR in future)
- ⚠️ **No metrics**: No Prometheus/StatsD integration yet
- ⚠️ **No health checks**: Services don't have built-in health check endpoints

### Next Up (Priority Order)
1. **Auto-registration**: Manager should auto-register deployments with Restate
2. **Production hardening**: Better error handling, logging, edge cases
3. **Metrics**: Add Prometheus metrics endpoint to Manager
4. **S3 backend**: Support `s3://` URLs for bundle sources
5. **Health checks**: Add health check endpoints and Kubernetes readiness probes
6. **Multi-node**: Design clustering strategy for horizontal scaling
7. **Web UI**: Simple web interface for deployment management

## Future Enhancements

- S3 backend for code bundles
- HTTPS download support
- Hash verification (SHA256)
- Multi-region code sync
- Metrics and observability
- Web UI for deployment management

## References

- [Restate Documentation](https://docs.restate.dev/)
- [Restate TypeScript SDK](https://github.com/restatedev/sdk-typescript)
- [workerd GitHub](https://github.com/cloudflare/workerd)
- [workerd Configuration](https://github.com/cloudflare/workerd/blob/main/src/workerd/server/workerd.capnp)
- [runit Documentation](http://smarden.org/runit/)
- [Crystal Language](https://crystal-lang.org/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/)
