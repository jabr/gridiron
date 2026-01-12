# Gridiron Demo - Getting Started

This hands-on tutorial walks you through building, deploying, and experiencing **hot code deployment** with Gridiron. You'll deploy two services, test them, and then update one to see zero-downtime deployment in action.

## Prerequisites

- Docker
- `curl` and `jq` (for API calls and JSON formatting)
- Node.js and npm (for building services)

## Part 1: Build Gridiron

```bash
# Build the Docker image
just docker-build

# Start the container
just docker-run

# Check everything is healthy
just status
```

## Part 2: Build the Demo Services

Gridiron deploys pre-built service bundles. Let's build our two demo services:

```bash
cd demo

# Build Counter service
cd counter
npm install
npx wrangler deploy --dry-run --outdir=dist/
cd ..

# Build Greeter service
cd greeter
npm install
npx wrangler deploy --dry-run --outdir=dist/
cd ..
```

Each `dist/` directory now contains:
- `index.js` - Bundled service code
- `sdk_shared_core_wasm_bindings_bg.wasm` - WASM runtime

## Part 3: Deploy to Gridiron

Copy the bundles into the container and deploy via the Manager API:

```bash
# Copy bundles to container
docker cp counter/dist gridiron:/tmp/counter-v1
docker cp greeter/dist gridiron:/tmp/greeter-v1

# Deploy Counter (version 1.0.0)
curl -X POST http://localhost:8081/activate \
  -H 'Content-Type: application/json' \
  -d '{"source": "file:///tmp/counter-v1", "name": "counter", "version": "1.0.0"}'

# Deploy Greeter (version 1.0.0)
curl -X POST http://localhost:8081/activate \
  -H 'Content-Type: application/json' \
  -d '{"source": "file:///tmp/greeter-v1", "name": "greeter", "version": "1.0.0"}'
```

Check your deployments:

```bash
# Manager
curl http://localhost:8081/deployments | jq
# Restate
curl http://localhost:9070/deployments | jq
```

## Part 4: Test the Services

### Greeter Service

```bash
# Health check
curl -X POST http://localhost:8080/Greeter/ping -d '{}'
# → "pong"

# Get a greeting
curl -X POST http://localhost:8080/Greeter/greet -d '"World"'
# → "Hello, World! Welcome to Gridiron (v1.0.0)"

# Check version
curl -X POST http://localhost:8080/Greeter/getVersion -d '{}'
# → {"service":"Greeter","version":"1.0.0"}
```

### Counter Service (Virtual Object)

Each counter key maintains independent state:

```bash
# Start a counter
curl -X POST http://localhost:8080/Counter/myCounter/get -d '{}'
# → 0 (starts at zero)

# Increment it
curl -X POST http://localhost:8080/Counter/myCounter/increment -d '{}'
# → 1

# Add 5
curl -X POST http://localhost:8080/Counter/myCounter/add -d '5'
# → 6

# Different key, different state
curl -X POST http://localhost:8080/Counter/otherCounter/get -d '{}'
# → 0 (independent counter)
```

## Part 5: Hot Code Deployment Demo

Now for the fun part - zero-downtime deployment. We'll update Greeter to v2.0.

### 1. Make a Code Change

Edit `greeter/src/index.ts` and change the greeting message:

```typescript
// Change this line:
const greeting = `Hello, ${name}! Welcome to Gridiron`;
// To:
const greeting = `Greetings, ${name}! Welcome to Gridiron`;
```

### 3. Build and Deploy

```bash
cd greeter
npx wrangler deploy --dry-run --outdir=dist/
cd ..

# Copy and deploy - no version number needed!
docker cp greeter/dist gridiron:/tmp/greeter-new

curl -X POST http://localhost:8081/activate \
  -H 'Content-Type: application/json' \
  -d '{"source": "file:///tmp/greeter-new", "name": "greeter"}'
```

Notice we don't specify a version - Gridiron generates a unique ID automatically (e.g., `greeter-1771295390.123-cfkv`).

### 4. Observe Both Versions Running

Both versions are now active simultaneously:

```bash
# Check deployments - both versions exist
curl http://localhost:8081/deployments | jq '.deployments[].build_id'
# → counter-1771..., greeter-1771..., greeter-1771...

# New calls use the new version with "Greetings"
curl -X POST http://localhost:9070/Greeter/greet -H "Content-Type: application/json" -d '"World"'
# → "Greetings, World! Welcome to Gridiron"
```

### 5. Clean Up Old Version

When the old version has no active invocations, you can remove it:

```bash
# Check if old version is still needed (look for active invocations)
docker exec gridiron sh -c 'restate sql "SELECT COUNT(*) FROM sys_invocation WHERE pinned_deployment_id = \"OLD_DEPLOYMENT_ID\""'

# When count is 0, remove from Restate and Gridiron
# (Manual cleanup for now - automatic pruning coming soon!)
```

## What Just Happened?

Gridiron uses **parallel deployments** with path-based routing:

1. **Initial**: workerd offers `/greeter-1771295390.123-abc1`, Restate routes to it
2. **New Deploy**: You changed "Hello" to "Greetings" and deployed
3. **Parallel**: workerd now offers BOTH the old AND new service (e.g., `/greeter-1771295390.123-abc1` AND `/greeter-1771295401.456-xyz9`)
4. **Routing**: New calls go to new version, in-flight calls continue on old version
5. **Drained**: When old version has 0 active calls, it can be removed

**Why this matters:**
- **Zero Downtime**: New version activates immediately
- **Safety**: Old version stays alive until all executions complete
- **Determinism**: Restate replays logs against the exact same code version
- **Simplicity**: No version numbers to manage - unique IDs are automatic

## Next Steps

### Try It Yourself

1. **Modify Counter**: Add a `multiply(n)` handler, deploy as v2.0.0, watch it deploy
2. **Create Your Own Service**: Copy `demo/greeter/` to `demo/my-service/`, customize, deploy
3. **Break Things**: Stop the container mid-deployment, restart it, see how it recovers

### Learn More

- **[DEPLOY.md](../DEPLOY.md)** - Detailed deployment guide for your own services
- **[AGENTS.md](../AGENTS.md)** - Architecture and design decisions

## Troubleshooting

**Services not responding:**
```bash
docker ps | grep gridiron          # Check container is running
just status                         # Check component status
docker logs gridiron | tail -20    # Check logs
```

**Build errors:**
```bash
rm -rf node_modules dist           # Clean and rebuild
npm install
npx wrangler deploy --dry-run --outdir=dist/
```

**Deployment not found:**
```bash
# Verify bundle path exists in container
docker exec gridiron ls -la /tmp/greeter-v2/
```
