# Gridiron - Restate + workerd distributed compute mesh
# Multi-stage build for minimal runtime image

# =============================================================================
# Stage 1: Builder - Download binaries and build manager
# =============================================================================
FROM crystallang/crystal:latest AS builder

WORKDIR /build

# Install build tools including npm for workerd
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    xz-utils \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Download Restate server binary
ARG RESTATE_VERSION=1.6.2
RUN wget -O restate.tar.xz \
    https://github.com/restatedev/restate/releases/download/v${RESTATE_VERSION}/restate-server-x86_64-unknown-linux-musl.tar.xz \
    && tar -xf restate.tar.xz \
    && mv restate-server-x86_64-unknown-linux-musl/restate-server /usr/local/bin/restate-server

# Download workerd via npm
ARG WORKERD_VERSION=1.20260214.0
RUN npm install -g workerd@${WORKERD_VERSION}

# Build the manager (Crystal)
COPY manager/ /build/manager/
WORKDIR /build/manager
RUN shards install && crystal build --release src/manager.cr -o /usr/local/bin/manager

# =============================================================================
# Stage 2: Runtime - Minimal image with just what we need
# =============================================================================
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    runit \
    sudo \
    ca-certificates \
    curl \
    jq \
    netcat-traditional \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install Restate CLI
RUN npm install -g @restatedev/restate

# Create gridiron user with sudo access for runit
RUN useradd -r -s /bin/false -u 1000 gridiron && \
    echo "gridiron ALL=(root) NOPASSWD: /usr/bin/sv stop workerd, /usr/bin/sv start workerd" >> /etc/sudoers.d/gridiron && \
    chmod 440 /etc/sudoers.d/gridiron

# Copy binaries from builder
COPY --from=builder /usr/local/bin/restate-server /usr/local/bin/
COPY --from=builder /usr/local/bin/workerd /usr/local/bin/
COPY --from=builder /usr/local/bin/manager /usr/local/bin/

# Copy configuration files
COPY config/ /opt/gridiron/config/

# Copy runit service definitions
COPY runit/ /etc/service/
RUN chmod +x /etc/service/*/run && \
    find /etc/service -name "run" -type f -exec chmod +x {} \;

# Copy scripts
COPY scripts/ /opt/gridiron/scripts/
RUN chmod +x /opt/gridiron/scripts/*.sh

# Create data directories and set permissions
RUN mkdir -p /run /data/restate /data/bundles /data/manager /data/logs \
    /data/logs/restate /data/logs/workerd /data/logs/manager \
    && chown -R gridiron:gridiron /data /run

# Set permissions on config directory
RUN chown -R gridiron:gridiron /opt/gridiron/config \
    && chmod -R 644 /opt/gridiron/config/*

# Expose ports
# 9070: Restate admin API (default)
# 8080: Restate user ingress (default)
# 5122: Restate internal fabric (default)
# 8081: Manager HTTP API
# 9080: Workerd TCP (for discovery and invocations)
EXPOSE 9070 8080 5122 8081 9080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD ["/opt/gridiron/scripts/health-check.sh"]

# Bootstrap and start runit supervision
ENTRYPOINT ["/opt/gridiron/scripts/bootstrap.sh"]
