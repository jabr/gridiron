#!/bin/bash
# Check status of Gridiron components
# Usage: ./status.sh [deployments|restate|workerd|all] [id]

set -e

RESTATE_ADMIN="${RESTATE_ADMIN:-http://localhost:9070}"
MANAGER_URL="${MANAGER_URL:-http://localhost:8081}"

show_usage() {
  echo "Usage: $0 [deployments|restate|workerd|all] [id]"
  echo ""
  echo "Examples:"
  echo "  $0 all                          # Show all status"
  echo "  $0 deployments                  # List all deployments"
  echo "  $0 deployments greeter-1.0.0    # Check specific deployment"
  echo "  $0 restate                      # Check Restate health"
  echo "  $0 workerd                      # Check workerd status"
}

show_restate_status() {
  echo "=== Restate Status ==="
  docker exec gridiron sv status restate
  if curl -sf "${RESTATE_ADMIN}/health" > /dev/null 2>&1; then
    echo "Status: HEALTHY"
  else
    echo "Status: UNHEALTHY or not running"
    return 1
  fi

  echo ""
  echo "Deployments:"
  curl -s "${RESTATE_ADMIN}/deployments" 2>/dev/null | jq -r '.deployments[] | "  - \(.id): \(.uri) (active: \(.active_invocations))"' 2>/dev/null || echo "  No deployments found"

  echo ""
  echo "Services:"
  curl -s "${RESTATE_ADMIN}/services" 2>/dev/null | jq -r '.services[] | "  - \(.name)"' 2>/dev/null || echo "  No services registered"
}

show_workerd_status() {
  echo "=== Workerd Status ==="
  docker exec gridiron sv status workerd

  if docker exec gridiron test -f /opt/gridiron/config/workerd.capnp 2>/dev/null; then
    echo "Config: EXISTS"
    echo ""
    echo "Active paths:"
    docker exec gridiron grep "path = " /opt/gridiron/config/workerd.capnp 2>/dev/null | sed 's/.*path = "\([^"]*\)".*/  - \/\1/' || echo "  No paths configured"
  else
    echo "Config: NOT FOUND"
  fi
}

show_manager_status() {
  echo "=== Manager Status ==="
  docker exec gridiron sv status manager
  if curl -sf "${MANAGER_URL}/health" > /dev/null 2>&1; then
    echo "Status: HEALTHY"
  else
    echo "Status: UNHEALTHY or not running"
  fi
}

show_deployments() {
  echo "=== Manager Deployments ==="
  if [ -n "$1" ]; then
    # Show specific deployment
    curl -s "${MANAGER_URL}/deployments/$1" 2>/dev/null | jq . || echo "Deployment not found"
  else
    # List all
    curl -s "${MANAGER_URL}/deployments" 2>/dev/null | jq -r '.deployments[] | "\(.build_id): \(.status) (deployment: \(.deployment_id // "N/A"))"' 2>/dev/null || echo "No deployments found"
  fi
}

case "${1:-all}" in
  restate)
    show_restate_status
    ;;
  workerd)
    show_workerd_status
    ;;
  manager)
    show_manager_status
    ;;
  deployments)
    show_deployments "$2"
    ;;
  all|*)
    show_restate_status
    echo ""
    show_workerd_status
    echo ""
    show_manager_status
    echo ""
    show_deployments
    ;;
esac
