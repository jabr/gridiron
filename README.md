# Gridiron

> A durable compute mesh that weaves Restate's permanent event log with workerd's low-latency V8 isolates into a single, self-healing grid for stateful processing.

## What is Gridiron?

Gridiron combines two powerful technologies:

- **[Restate](https://restate.dev/)**: Durable execution orchestration with virtual objects and persistent state
- **[workerd](https://github.com/cloudflare/workerd)**: Cloudflare's open-source Workers runtime (V8 isolates)

Together, they create a distributed compute mesh where:
- Worker code runs in ultra-fast V8 isolates (millisecond cold starts)
- State is durable and survives crashes via Restate's event log
- Hot code deployment allows zero-downtime updates via path-based versioning

## Quick Demo

```bash
# Build and start
just docker-build && just docker-run

# Build and deploy the demo services
just deploy-demo

# Test it out
just test-greeter
# => "Hello, World! ..."
just test-greeter friend
# => "Hello, friend! ..."
just test-counter
# => 1
just test-counter
# => 2
just test-counter other-key
# => 1
just test-counter
# => 3

# Stop everything
just docker-clean
```

See [demo/GETTING_STARTED.md](demo/GETTING_STARTED.md) for a complete step-by-step tutorial.

## What Can Gridiron Do For You?

**For Application Developers:**
- Deploy serverless functions with durable state
- Update code without downtime - in-flight executions finish on the old version, new calls go to the new version
- Write stateful services in familiar TypeScript/Cloudflare Workers SDK
- State persists across crashes and restarts automatically

**For Platform Teams:**
- Zero-downtime deployments with automatic version management
- Independent service lifecycles - update services without affecting others
- Simple, focused deployment manager

## Architecture

```
┌───────────────────────────────────────────────────────────┐
│                    Gridiron Container                     │
│                                                           │
│  ┌───────────┐      ┌─────────────┐     ┌──────────────┐  │
│  │  Restate  │◄────►│   workerd   │◄───►│   Manager    │  │
│  │   Server  │      │(V8 Isolates)│     │              │  │
│  │           │      │             │     │              │  │
│  │9070/8080  │      │ 9080 (TCP)  │     │     8081     │  │
│  └───────────┘      └─────────────┘     └──────────────┘  │
│       │                    │                    │         │
│       │                    │                    │         │
│    RocksDB           Code Bundles          Config Gen     │
│    (State)          (/data/bundles)      (workerd.capnp)  │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

**Key Components:**
- **Restate Server**: Durable execution orchestration (Rust)
- **workerd**: V8 isolate-based JavaScript execution (C++)
- **Manager**: Deployment management sidecar

## Features

- ✅ **Durable Execution**: Workflows survive crashes via Restate's event log
- ✅ **Virtual Objects**: Stateful actors with single-writer consistency
- ✅ **Hot Code Deployment**: Zero-downtime updates via path-based versioning
- ✅ **Fast Cold Starts**: V8 isolates start in milliseconds
- ✅ **Simple**: Minimal, focused deployment manager
- ✅ **Self-Healing**: Automatic restart via runit

## Documentation

- **[demo/GETTING_STARTED.md](demo/GETTING_STARTED.md)** - Step-by-step tutorial: build, deploy, and experience hot code deployment
- **[DEPLOY.md](DEPLOY.md)** - Deploying your own services, API reference, troubleshooting
- **[AGENTS.md](AGENTS.md)** - Architecture details and design decisions
- **[manager/README.md](manager/README.md)** - Manager service documentation

## Technology Stack

- **Restate**: Rust, durable execution engine
- **workerd**: C++, V8 isolate runtime
- **Manager**: Deployment management service
- **Services**: TypeScript + Wrangler (Cloudflare Workers SDK)
- **Supervision**: runit (C-based)
- **Build**: Just (command runner)

## License

MIT
