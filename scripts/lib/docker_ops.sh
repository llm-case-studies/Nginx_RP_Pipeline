#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# shellcheck source=core.sh
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

ensure_network() {
  log "🌐" "Ensuring network ${NETWORK_NAME:-unset}"
}

dk_run() {
  log "🐳" "Starting ${CONTAINER_NAME:-container} with image ${IMAGE:-image}"
}

dk_stop() {
  log "🛑" "Stopping ${CONTAINER_NAME:-container}"
}

probe_http() {
  require_cmd curl
  local url=$1
  curl --silent --fail --max-time 2 "$url" >/dev/null
}
