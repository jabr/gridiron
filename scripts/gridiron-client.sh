#!/bin/bash
# Gridiron Client - Call Restate services from outside the container
# Usage: ./gridiron-client.sh <service> <handler> [key] [data]

set -e

# Default to localhost if not specified
RESTATE_HOST="${RESTATE_HOST:-localhost}"
RESTATE_PORT="${RESTATE_PORT:-9070}"
BASE_URL="http://${RESTATE_HOST}:${RESTATE_PORT}"

show_usage() {
  echo "Usage: $0 <service> <handler> [key] [data]"
  echo ""
  echo "Examples:"
  echo "  $0 Counter increment my-counter"
  echo "  $0 Counter get my-counter"
  echo "  $0 Greeter greet - '{\"name\": \"World\"}'"
  echo ""
  echo "Environment:"
  echo "  RESTATE_HOST - Restate host (default: localhost)"
  echo "  RESTATE_PORT - Restate port (default: 9070)"
}

if [ $# -lt 2 ]; then
  show_usage
  exit 1
fi

SERVICE="$1"
HANDLER="$2"
shift 2
# Check if next arg is a key (doesn't start with { or [)
if [ $# -gt 0 ] && [[ ! "$1" =~ ^[\{\[] ]]; then
  KEY="$1"
  shift
else
  KEY=""
fi

# Remaining args are the request body
if [ $# -gt 0 ]; then
  BODY="$1"
else
  BODY='{}'
fi

# Build URL
if [ -n "$KEY" ]; then
  URL="${BASE_URL}/${SERVICE}/${KEY}/${HANDLER}"
else
  URL="${BASE_URL}/${SERVICE}/${HANDLER}"
fi

echo "Calling: ${URL}"
echo "Body: ${BODY}"
echo ""

# Make the request
if command -v curl &> /dev/null; then
  curl -X POST "${URL}" \
    -H "Content-Type: application/json" \
    -d "${BODY}" | jq .
elif command -v wget &> /dev/null; then
  wget -qO- "${URL}" \
    --post-data="${BODY}" \
    --header="Content-Type: application/json" | jq .
else
  echo "Error: curl or wget required"
  exit 1
fi
