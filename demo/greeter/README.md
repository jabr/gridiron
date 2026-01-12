# Greeter Service

A simple Restate service demonstrating stateless request/response handlers with Gridiron.

## Overview

The Greeter service provides basic request/response functionality. It's stateless (no durable state) and is useful for health checks and testing deployments.

## Handlers

- **greet(name)** - Returns a personalized greeting message including the version
- **ping()** - Health check endpoint, returns "pong"
- **getVersion()** - Returns the service version (useful for hot deployment demos)

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
# Get a greeting
curl -X POST http://localhost:8080/Greeter/greet \
  -H 'Content-Type: application/json' \
  -d '"World"'

# Health check
curl -X POST http://localhost:8080/Greeter/ping \
  -H 'Content-Type: application/json' \
  -d '{}'

# Check the version
curl -X POST http://localhost:8080/Greeter/getVersion \
  -H 'Content-Type: application/json' \
  -d '{}'
```
