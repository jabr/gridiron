# Deploying Services with Gridiron

This guide covers deploying your own services to Gridiron. For a hands-on tutorial, see [demo/GETTING_STARTED.md](demo/GETTING_STARTED.md).

## Quick Start

```bash
# 1. Build and start Gridiron
just docker-build && just docker-run

# 2. Build your service
cd my-service
npm install
npx wrangler deploy --dry-run --outdir=dist/

# 3. Deploy to Gridiron
docker cp dist gridiron:/tmp/my-service-v1
curl -X POST http://localhost:8081/activate \
  -H 'Content-Type: application/json' \
  -d '{"source": "file:///tmp/my-service-v1", "name": "my-service", "version": "1.0.0"}'

# 4. Register with Restate
docker exec gridiron sh -c 'restate deployment register --yes --use-http1.1 http://localhost:9080'
```

## Service Development

### Project Structure

A Gridiron service is a standard Cloudflare Workers project:

```
my-service/
├── src/
│   └── index.ts          # Service handlers
├── package.json          # Dependencies
└── wrangler.toml         # Wrangler config
```

### Example Service

```typescript
import * as restate from "@restatedev/restate-sdk-cloudflare-workers/fetch";

const myService = restate.service({
  name: "MyService",
  handlers: {
    async process(ctx, input: string) {
      ctx.console.log(`Processing: ${input}`);
      return `Processed: ${input}`;
    }
  }
});

export default {
  fetch: restate.createEndpointHandler({ services: [myService] })
};
```

### Building

```bash
npm install
npx wrangler deploy --dry-run --outdir=dist/
```

The `dist/` directory will contain:
- `index.js` - Bundled code
- `sdk_shared_core_wasm_bindings_bg.wasm` - WASM runtime

## Deployment API

### Activate (Deploy)

```bash
curl -X POST http://localhost:8081/activate \
  -H 'Content-Type: application/json' \
  -d '{
    "source": "file:///path/to/bundle",
    "name": "my-service",
    "version": "1.0.0"
  }'
```

**Response:**
```json
{
  "build_id": "my-service-1.0.0-1708012345",
  "path": "/my-service/1.0.0-1708012345",
  "status": "active"
}
```

**What happens:**
1. Manager copies bundle to `/data/bundles/`
2. Generates new `workerd.capnp` with path-based route
3. Restarts workerd via runit
4. (Future: Auto-registers with Restate)

### List Deployments

```bash
curl http://localhost:8081/deployments
```

### Get Deployment Details

```bash
curl http://localhost:8081/deployments/my-service-1.0.0-1708012345
```

### Prune (Remove Old Version)

```bash
curl -X POST http://localhost:8081/prune \
  -H 'Content-Type: application/json' \
  -d '{"build_id": "my-service-1.0.0-1708012345"}'
```

**Note:** Old versions are auto-pruned after 30 seconds when they have 0 active invocations.

## Service Types

### Stateless Services

Simple request/response handlers:

```typescript
const greeter = restate.service({
  name: "Greeter",
  handlers: {
    async greet(ctx, name: string) {
      return `Hello, ${name}!`;
    }
  }
});
```

### Virtual Objects (Stateful)

Objects with durable state, identified by key:

```typescript
const counter = restate.object({
  name: "Counter",
  handlers: {
    async increment(ctx) {
      const count = (await ctx.get("count")) ?? 0;
      ctx.set("count", count + 1);
      return count + 1;
    }
  }
});
```

Call with key: `POST /Counter/my-key/increment`

## Testing Services

### Via curl

```bash
# Stateless service
curl -X POST http://localhost:8080/Greeter/greet \
  -H 'Content-Type: application/json' \
  -d '"World"'

# Virtual object (with key)
curl -X POST http://localhost:8080/Counter/my-key/increment
```

### Via CLI

```bash
just call Greeter greet - '"World"'
just call Counter increment my-key
```

### Service Discovery

```bash
# List Restate services
curl http://localhost:9070/services

# List deployments
curl http://localhost:9070/deployments

# Check Manager deployments
curl http://localhost:8081/deployments
```

## Monitoring

### View Logs

```bash
# All logs
just docker-logs

# Component-specific
docker exec gridiron tail -f /data/logs/restate/current
docker exec gridiron tail -f /data/logs/workerd/current
docker exec gridiron tail -f /data/logs/manager/current
```

### Check Status

```bash
just status              # All components
curl http://localhost:9070/health    # Restate
curl http://localhost:8081/health    # Manager
```

## Troubleshooting

### Services Not Responding

```bash
# Check container
docker ps | grep gridiron

# Check logs
just docker-logs

# Verify deployment
curl http://localhost:8081/deployments

# Check Restate registration
curl http://localhost:9070/services
```

### Build Errors

```bash
# Clean rebuild
rm -rf node_modules dist
npm install
npx wrangler deploy --dry-run --outdir=dist/
```

### Deployment Failures

```bash
# Verify bundle structure
docker exec gridiron ls -la /data/bundles/my-service-1.0.0-*/

# Should show: index.js, sdk_shared_core_wasm_bindings_bg.wasm, metadata.json
```

### Port Conflicts

```bash
# Use different ports
docker run -d \
  -p 19070:9070 \
  -p 18080:8080 \
  -p 15122:5122 \
  -p 18081:8081 \
  -p 19080:9080 \
  gridiron:latest
```

## Next Steps

- **Build your first service** - Start with the demo services as templates
- **Read AGENTS.md** - Understand the architecture
- **Check the Manager API** - Full API documentation in manager/README.md

## Reference

### Port Allocation

- **5122**: Restate internal fabric
- **9070**: Restate Admin API
- **8080**: Restate user ingress
- **8081**: Manager HTTP API
- **9080**: Workerd discovery (TCP)

### Just Commands

```bash
just docker-build        # Build image
just docker-run          # Start container
just docker-logs         # View logs
just docker-clean        # Stop and remove
just status              # Check status
just call ...            # Call service
```
