# Manager Service

## Overview
The manager service handles:
1. Receiving and storing code bundles
2. Generating workerd configuration
3. Registering deployments with Restate
4. Monitoring and pruning old versions

## Building

```bash
# Install dependencies
shards install

# Development build (fast)
crystal build src/manager.cr -o bin/manager

# Production build (optimized)
crystal build --release src/manager.cr -o bin/manager

# Or use Justfile
just build-manager
```

## Running

```bash
# Set environment variables (optional - has defaults)
export MANAGER_PORT=8081
export BUNDLES_DIR=/data/bundles
export MANAGER_STATE_DIR=/data/manager
export WORKERD_CONFIG_PATH=/opt/gridiron/config/workerd.capnp
export WORKERD_TEMPLATE_PATH=/opt/gridiron/config/workerd-template.capnp
export RESTATE_ADMIN_URL=http://localhost:9070
# Run
./bin/manager
```

## API

The manager exposes an HTTP API:

### POST /activate
Activate a new code version.

Request:
```json
{
  "source": "file:///path/to/bundle/directory",
  "name": "greeter",
  "version": "1.0.0"
}
```

Response:
```json
{
  "status": "activated",
  "build_id": "greeter-1.0.0-1234567890",
  "path": "/greeter/1.0.0-1234567890",
  "message": "Version activated..."
}
```

### POST /prune
Remove an old version.

Request:
```json
{
  "build_id": "greeter-1.0.0-1234567890",
  "deployment_id": "optional-restate-deployment-id"
}
```

### GET /deployments
List all deployments.

Response:
```json
{
  "deployments": [
    {
      "build_id": "greeter-1.0.0-1234567890",
      "metadata": {...},
      "path": "/greeter/1.0.0-1234567890",
      "status": "Active",
      "deployment_id": "dp_..."
    }
  ]
}
```

### GET /health
Health check. Returns "OK".

## State Storage

State is stored as JSON files in `/data/manager/`:
- `state.json` - Deployment registry
- `bundles/` - Code bundles with metadata

## Directory Structure

```
manager/
├── src/
│   ├── manager.cr      # Entry point
│   ├── config.cr       # Configuration
│   ├── state.cr        # State management
│   ├── handlers.cr     # HTTP handlers
│   ├── restate_client.cr  # Restate API client
│   ├── workerd_manager.cr # Workerd config management
│   └── models.cr       # Data models
├── spec/               # Tests
├── shard.yml           # Dependencies (empty - zero deps!)
└── README.md           # This file
```

## Zero Dependencies

The Manager uses only Crystal's standard library - no external shards required!
