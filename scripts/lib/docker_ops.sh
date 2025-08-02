#!/usr/bin/env bash
#-------------------------------------------------------------
# docker_ops.sh – container‑helper layer for safe-rp-ctl
#-------------------------------------------------------------
# Relies on Docker + curl.  All logging / error handling flows
# through core.sh helper functions.
#-------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

# Bring in core helpers -------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core.sh
source "$SCRIPT_DIR/core.sh"

require_cmd docker
require_cmd curl

# ensure_network [network_name]
# Idempotently create a user-defined bridge network. Uses NETWORK_NAME
# env var if no argument is provided.
ensure_network() {
  local net="${1:-${NETWORK_NAME:-}}"
  [[ -n "$net" ]] || die "Network name required"
  if docker network inspect "$net" >/dev/null 2>&1; then
    log_info "Docker network '$net' already exists."
  else
    log_info "Creating Docker network '$net'"
    docker network create "$net" >/dev/null
    log_success "Network '$net' created."
  fi
}

# dk_stop [container_name] – stop & remove quietly
dk_stop() {
  local name="${1:-${CONTAINER_NAME:-}}"
  [[ -n "$name" ]] || die "Container name required"
  log_info "Stopping container $name (if running)"
  docker stop "$name" >/dev/null 2>&1 || true
  docker rm "$name" >/dev/null 2>&1 || true
}

# dk_run – run container with common flags
#   expects env vars:
#     IMAGE           (default nginx:latest)
#     CONTAINER_NAME  (required)
#     NETWORK_NAME    (optional)
#     HTTP_PORT / HTTPS_PORT  (host ports; defaults 8080/8443)
#     VOLUME_FLAGS    (string of -v mounts)
#     EXTRA_DOCKER_OPTS (free-form)
dk_run() {
  : "${CONTAINER_NAME:?CONTAINER_NAME not set}"
  local image="${IMAGE:-nginx:latest}"
  local http_p="${HTTP_PORT:-8080}"
  local https_p="${HTTPS_PORT:-8443}"

  dk_stop "$CONTAINER_NAME"

  local cmd=( docker run -d
              --name "$CONTAINER_NAME"
              -p "${http_p}:80"
              -p "${https_p}:443" )

  if [[ -n "${NETWORK_NAME:-}" ]]; then
    ensure_network "$NETWORK_NAME"
    cmd+=( --network "$NETWORK_NAME" )
  fi

  if [[ -n "${VOLUME_FLAGS:-}" ]]; then
    # shellcheck disable=SC2206  # we want word-splitting on VOLUME_FLAGS
    local vols=( $VOLUME_FLAGS )
    cmd+=( "${vols[@]}" )
  fi

  if [[ -n "${EXTRA_DOCKER_OPTS:-}" ]]; then
    # shellcheck disable=SC2206
    local extra=( $EXTRA_DOCKER_OPTS )
    cmd+=( "${extra[@]}" )
  fi

  cmd+=( "$image" )

  log_info "Running container: ${cmd[*]}"
  "${cmd[@]}" >/dev/null
  log_success "Container $CONTAINER_NAME started."
}

# probe_http <url> [retries] [delay]
# Returns 0 if the endpoint returns HTTP 200 within retries
probe_http() {
  local url="$1"; local retries="${2:-10}"; local delay="${3:-2}"
  local attempt=1
  while (( attempt <= retries )); do
    if curl --silent --fail --max-time 2 "$url" >/dev/null; then
      log_success "Health check succeeded on attempt $attempt/$retries"
      return 0
    fi
    log_warn "Health check failed ($attempt/$retries)… retrying in ${delay}s"
    sleep "$delay"
    (( attempt++ ))
  done
  log_error "Health check FAILED after $retries attempts"
  return 1
}

