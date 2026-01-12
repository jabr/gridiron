# Gridiron Demo Service

A sample Restate service built with the Cloudflare Workers SDK, bundled with Wrangler, and deployable via the Gridiron Manager.

## Services

- **Counter** - Virtual object with durable state
  - `get()` - Get current count
  - `increment()` - Increment by 1
  - `add(n)` - Add n to counter
  - `reset()` - Reset to 0

- **Greeter** - Simple request/response service
  - `greet(name)` - Return greeting
  - `ping()` - Health check

## Building

```bash
# Install dependencies
npm install

# Build with wrangler (creates dist/ directory)
npx wrangler deploy --dry-run --outdir=dist/

# The dist/ directory contains:
# - index.js (bundled code)
# - sdk_shared_core_wasm_bindings_bg.wasm (WASM runtime)
```

## Deploying

Via Gridiron Manager API:

```bash
# Copy dist to container
docker cp dist gridiron:/tmp/demo-service

# Rename WASM file
docker exec gridiron sh -c "cd /tmp/demo-service && mv *-sdk_shared_core_wasm_bindings_bg.wasm sdk_shared_core_wasm_bindings_bg.wasm"

# Deploy via Manager
curl -X POST http://localhost:8081/activate \
  -H 'Content-Type: application/json' \
  -d '{"source": "file:///tmp/demo-service", "name": "demo", "version": "1.0.0"}'

# Register with Restate
docker exec gridiron sh -c 'restate deployment register --yes --use-http1.1 http://localhost:9080'
```

## Development

Edit `src/index.ts` to add/modify services:

```typescript
import * as restate from "@restatedev/restate-sdk-cloudflare-workers/fetch";

const myService = restate.service({
  name: "MyService",
  handlers: {
    async myHandler(ctx, input) {
      return `Result: ${input}`;
    }
  }
});

export default {
  fetch: restate.createEndpointHandler({ services: [myService] })
};
```

## Technology

- **Runtime**: Cloudflare Workers SDK (@restatedev/restate-sdk-cloudflare-workers)
- **Bundler**: Wrangler
- **Language**: TypeScript
- **Deployment**: Via Gridiron Manager
