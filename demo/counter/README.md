# Counter Service

A Restate virtual object service demonstrating durable state with Gridiron.

## Overview

The Counter service maintains state per unique key. Each counter is independent and its state persists across invocations.

## Handlers

- **get()** - Returns the current count for this counter
- **increment()** - Increments the counter by 1 and returns the new value
- **add(n)** - Adds n to the counter and returns the new value
- **reset()** - Resets the counter to 0
- **getVersion()** - Returns the service version and key (useful for hot deployment demos)

## Building

```bash
# Install dependencies
npm install

# Build with wrangler
npx wrangler deploy --dry-run --outdir=dist/

# The dist/ directory contains:
# - index.js (bundled code)
# - sdk_shared_core_wasm_bindings_bg.wasm (WASM runtime)
```

## Example Usage

```bash
# Get current count (starts at 0)
curl -X POST http://localhost:8080/Counter/myCounter/get \
  -H 'Content-Type: application/json' \
  -d '{}'

# Increment the counter
curl -X POST http://localhost:8080/Counter/myCounter/increment \
  -H 'Content-Type: application/json' \
  -d '{}'

# Add 5 to the counter  
curl -X POST http://localhost:8080/Counter/myCounter/add \
  -H 'Content-Type: application/json' \
  -d '5'

# Check the version
curl -X POST http://localhost:8080/Counter/myCounter/getVersion \
  -H 'Content-Type: application/json' \
  -d '{}'
```
