#!/bin/bash
# Health check script for Docker healthcheck

# Check if Restate is responding
if ! curl -f -s http://localhost:9070/health > /dev/null 2>&1; then
    echo "ERROR: Restate health check failed"
    exit 1
fi

# Check if workerd socket exists
if [ ! -S /run/workerd.sock ]; then
    echo "ERROR: workerd socket not found"
    exit 1
fi

echo "Health check passed"
exit 0
