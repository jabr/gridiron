# Gridiron - Build Commands

# Default recipe
default:
    @just --list

# =============================================================================
# Manager (Crystal)
# =============================================================================

# Build the manager binary
build-manager:
    cd manager && crystal build --release src/manager.cr -o bin/manager

# Build manager for development (faster compile)
dev-manager:
    cd manager && crystal build src/manager.cr -o bin/manager

# Format Crystal code
fmt-manager:
    cd manager && crystal tool format

# Clean manager build artifacts
clean-manager:
    rm -rf manager/bin/ manager/lib/

# =============================================================================
# Docker
# =============================================================================

# Build the Docker image
docker-build:
    docker build -t gridiron:latest .

# Run the container with all ports exposed
docker-run:
    docker run -d \
        --name gridiron \
        -p 9070:9070 \
        -p 8080:8080 \
        -p 5122:5122 \
        -p 8081:8081 \
        -p 9080:9080 \
        gridiron:latest

# Run with interactive shell
docker-interactive:
    docker run -it --rm \
        -p 9070:9070 \
        -p 8080:8080 \
        -p 5122:5122 \
        -p 8081:8081 \
        -p 9080:9080 \
        gridiron:latest /bin/bash

# Stop and remove container
docker-clean:
    docker stop gridiron || true
    docker rm gridiron || true

# View logs
docker-logs:
    docker logs -f gridiron

# Open shell on docker container
docker-shell:
  docker exec -it gridiron bash

# =============================================================================
# Operations (outside container)
# =============================================================================

# Check status of all components
status:
    ./scripts/status.sh all

# List deployments via Manager API
deployments:
    echo "Manager"
    curl -s http://localhost:8081/deployments | jq .
    echo "Restate"
    curl -s http://localhost:9070/deployments | jq .

# Deploy via Manager API
deploy-via-manager NAME VERSION BUNDLE_DIR:
    curl -X POST http://localhost:8081/activate \
        -H 'Content-Type: application/json' \
        -d '{"source": "file://{{BUNDLE_DIR}}", "name": "{{NAME}}", "version": "{{VERSION}}"}' | jq .

# Register deployed service with Restate CLI
register-with-restate SERVICE_PATH:
    docker exec gridiron sh -c 'restate deployment register --yes --use-http1.1 http://localhost:9080{{SERVICE_PATH}}'

# Register deployed service with Restate Admin API
register-with-api SERVICE_PATH:
    http -v :9070/v3/deployments uri=http://localhost:9080{{SERVICE_PATH}} use_http_11:=true

# Call a Restate service
call SERVICE HANDLER *ARGS:
    ./scripts/gridiron-client.sh {{SERVICE}} {{HANDLER}} {{ARGS}}

# Deploy demo services
deploy-demo uid=uuid():
    #!/usr/bin/env bash
    set -e
    echo "Building Counter service..."
    cd demo/counter && npm install && npx wrangler deploy --dry-run --outdir=dist/
    cd ../..
    echo "Building Greeter service..."
    cd demo/greeter && npm install && npx wrangler deploy --dry-run --outdir=dist/
    cd ../..
    echo "Copying to container..."
    docker cp demo/counter/dist gridiron:/tmp/counter.{{uid}}
    docker cp demo/greeter/dist gridiron:/tmp/greeter.{{uid}}
    echo "Deploying Counter via Manager..."
    curl -X POST http://localhost:8081/activate \
        -H 'Content-Type: application/json' \
        -d '{"source": "file:///tmp/counter.{{uid}}", "name": "counter", "version": "1.0.0"}' | jq .
    echo "Deploying Greeter via Manager..."
    curl -X POST http://localhost:8081/activate \
        -H 'Content-Type: application/json' \
        -d '{"source": "file:///tmp/greeter.{{uid}}", "name": "greeter", "version": "1.0.0"}' | jq .
    echo ""

# Test Counter service - increments counter and returns new value
test-counter key='mykey':
    #!/usr/bin/env bash
    set -e
    response=$(curl -s -X POST http://localhost:8080/Counter/{{key}}/increment)
    printf "%s\n" "$response"

# Test Greeter service (defaults to "World", pass a custom name as argument)
test-greeter name="World":
    #!/usr/bin/env bash
    set -e
    response=$(curl -s -X POST http://localhost:8080/Greeter/greet \
        -H "Content-Type: application/json" \
        -d '"{{name}}"')
    printf "%s\n" "$response"

# =============================================================================
# Demo Service (Wrangler/Node.js)
# =============================================================================

# Build demo services with wrangler
build-demo:
    cd demo/counter && npm install && npx wrangler deploy --dry-run --outdir=dist/
    cd ../greeter && npm install && npx wrangler deploy --dry-run --outdir=dist/

# Run demo service locally with wrangler dev (runs Counter on port 9080)
run-demo-counter:
    cd demo/counter && npx wrangler dev --port 9080

# Run demo service locally with wrangler dev (runs Greeter on port 9081)
run-demo-greeter:
    cd demo/greeter && npx wrangler dev --port 9081

# =============================================================================
# Combined Operations
# =============================================================================

# Build everything
build-all: build-manager build-demo docker-build

# Full clean
clean: clean-manager docker-clean
    rm -rf test_data/

# Quick test cycle: build, run, deploy demo
quick-test: docker-build docker-run
    #!/usr/bin/env bash
    set -e
    sleep 10
    echo "Deploying demo..."
    just deploy-demo
