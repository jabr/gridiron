#!/bin/bash
# Gridiron Bootstrap Script
# Initializes the container and starts runit service supervision

set -e

echo "=== Gridiron Bootstrap ==="
echo "Initializing distributed compute mesh..."

# Ensure data directories exist and have correct permissions
echo "Creating data directories..."
mkdir -p /run /data/restate /data/logs
chown -R gridiron:gridiron /data /run

# Create the Unix socket directory with correct permissions
mkdir -p /run
chmod 755 /run

echo "Data directories initialized"

# Wait a moment for filesystem to settle
sleep 1

# Start runit - it will manage our services
echo "Starting service supervision with runit..."
echo "Services: restate, workerd"
echo ""

# runsvdir will start all services in /etc/service
exec runsvdir /etc/service

echo "Services: restate, workerd, manager"
