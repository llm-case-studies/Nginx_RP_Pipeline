#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# shellcheck source=core.sh
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

dk_run() {
  require_cmd docker
  log_info "Starting ${CONTAINER_NAME:-container} with image ${IMAGE:-image}"
}

dk_stop() {
  require_cmd docker
  log_info "Stopping ${CONTAINER_NAME:-container}"
}

ensure_network() {
  require_cmd docker
  log_info "Ensuring network ${NETWORK_NAME:-unset}"
}

probe_http() {
  require_cmd curl
  local url=$1
  curl --silent --fail --max-time 2 "$url" >/dev/null
}
