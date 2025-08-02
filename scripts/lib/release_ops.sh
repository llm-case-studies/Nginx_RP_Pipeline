#!/usr/bin/env bash
#-------------------------------------------------------------
# release_ops.sh – implements the four public commands that
# safe‑rp‑ctl exposes:
#   rc_build_local   – dev laptop build + local replica
#   rc_start         – run packaged runtime on stage / preprod
#   rc_deploy_prod   – timestamped promotion + hot‑swap in prod
#   rc_rollback      – re‑mount older prod directory
#-------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core.sh
source "$SCRIPT_DIR/core.sh"
# shellcheck source=docker_ops.sh
source "$SCRIPT_DIR/docker_ops.sh"

### CONFIG ----------------------------------------------------------------
WORKSPACE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
INTAKE_DIR="/mnt/pipeline-intake"         # absolute, shared by app teams
RUNTIME_DIR="$WORKSPACE_ROOT/runtime"
PORT_TPL_DIR="$WORKSPACE_ROOT/ports"

# These envs can be overridden by caller
IMAGE="${IMAGE:-nginx:latest}"
NETWORK_NAME="rp-net"

############################################################################
# 1. rc_build_local – build candidate & run local container
############################################################################
rc_build_local() {
  log_info "🛠  Building local release‑candidate from artefacts in $INTAKE_DIR"
  require_cmd unzip
  gen_dev_certs

  [[ -d "$RUNTIME_DIR" ]] && rm -rf "$RUNTIME_DIR"
  mkdir -p "$RUNTIME_DIR/conf.d" "$RUNTIME_DIR/www" "$RUNTIME_DIR/logs"

  # Iterate over each .zip in intake
  mapfile -t zips < <(find "$INTAKE_DIR" -maxdepth 1 -type f -name '*.zip')
  if (( ${#zips[@]} == 0 )); then die "No artefacts found in $INTAKE_DIR"; fi

  for zip in "${zips[@]}"; do
    log_info "↳ Processing $(basename "$zip")"
    tmpdir=$(mktemp -d)
    unzip -q "$zip" -d "$tmpdir"
    # Expect structure: app.conf , dist/  (adjust as needed)
    if [[ -f "$tmpdir/nginx.conf" ]]; then
      mv "$tmpdir/nginx.conf" "$RUNTIME_DIR/nginx.conf"
    fi
    mv "$tmpdir"/*.conf              "$RUNTIME_DIR/conf.d/" 2>/dev/null || true
    if [[ -d "$tmpdir"/dist ]]; then
      appname="$(basename "$zip" .zip)"
      mkdir -p "$RUNTIME_DIR/www/$appname"
      mv "$tmpdir"/dist/* "$RUNTIME_DIR/www/$appname/" || true
    fi
    rm -rf "$tmpdir"
  done

  cp "$PORT_TPL_DIR/local.conf" "$RUNTIME_DIR/ports.conf"
  cp "$WORKSPACE_ROOT/conf.d"/*.conf "$RUNTIME_DIR/conf.d/" 2>/dev/null || true
  [[ -f "$RUNTIME_DIR/nginx.conf" ]] || cp "$WORKSPACE_ROOT/conf/nginx.conf" "$RUNTIME_DIR/nginx.conf"

  log_success "Runtime candidate built at $RUNTIME_DIR"

  # start local container --------------------------------------------------
  CONTAINER_NAME="rp-local"
  HTTP_PORT=8080 HTTPS_PORT=8443
  VOLUME_FLAGS="-v $RUNTIME_DIR/nginx.conf:/etc/nginx/nginx.conf:ro \
                -v $RUNTIME_DIR/conf.d:/etc/nginx/conf.d:ro          \
                -v $RUNTIME_DIR/ports.conf:/etc/nginx/ports.conf:ro  \
                -v $RUNTIME_DIR/www:/var/www:ro                      \
                -v $WORKSPACE_ROOT/certs:/etc/nginx/certs:ro         \
                -v $RUNTIME_DIR/logs:/var/log/nginx"
  dk_run
  probe_http "https://localhost:${HTTPS_PORT}/" 5 1
}

############################################################################
# 2. rc_start – run packaged runtime (stage / preprod)
############################################################################
rc_start() {
  local env=""
  if [[ "$1" == "--env" ]]; then shift; env="$1"; shift || true; fi
  [[ -z "$env" ]] && die "Usage: rc_start --env <stage|preprod>"

  case "$env" in
    stage)     CONTAINER_NAME="rp-stage"   ; cp "$PORT_TPL_DIR/stage.conf"   "$RUNTIME_DIR/ports.conf";;
    preprod)   CONTAINER_NAME="rp-preprod" ; cp "$PORT_TPL_DIR/preprod.conf" "$RUNTIME_DIR/ports.conf";;
    *) die "Unknown env $env";;
  esac

  HTTP_PORT=80  HTTPS_PORT=443   # host ports on servers
  VOLUME_FLAGS="-v $RUNTIME_DIR/nginx.conf:/etc/nginx/nginx.conf:ro \
                -v $RUNTIME_DIR/conf.d:/etc/nginx/conf.d:ro          \
                -v $RUNTIME_DIR/ports.conf:/etc/nginx/ports.conf:ro  \
                -v $RUNTIME_DIR/www:/var/www:ro                      \
                -v $RUNTIME_DIR/logs:/var/log/nginx"
  dk_run
  probe_http "https://localhost:443/" 5 2
}

############################################################################
# 3. rc_deploy_prod – promote to prod with timestamp dir
############################################################################
rc_deploy_prod() {
  local prod_root="/home/proxyuser"       # adjust to real prod path
  local ts="prod-$(now_ts)"
  local new_dir="$prod_root/Nginx-$ts"

  log_info "🚀 Promoting runtime to $new_dir"
  cp -r "$RUNTIME_DIR" "$new_dir"

  # Swap container
  CONTAINER_NAME="rp-prod"
  HTTP_PORT=80 HTTPS_PORT=443
  VOLUME_FLAGS="-v $new_dir/nginx.conf:/etc/nginx/nginx.conf:ro \
                -v $new_dir/conf.d:/etc/nginx/conf.d:ro          \
                -v $new_dir/ports.conf:/etc/nginx/ports.conf:ro  \
                -v $new_dir/www:/var/www:ro                      \
                -v $new_dir/logs:/var/log/nginx"
  dk_run
  probe_http "https://localhost/" 10 3
  log_success "Production now serving from $new_dir"
}

############################################################################
# 4. rc_rollback <prod-dir>
############################################################################
rc_rollback() {
  local dir="$1"
  [[ -d "$dir" ]] || die "Dir $dir not found"

  log_warn "Rolling back containers to $dir"
  CONTAINER_NAME="rp-prod"
  HTTP_PORT=80 HTTPS_PORT=443
  VOLUME_FLAGS="-v $dir/nginx.conf:/etc/nginx/nginx.conf:ro \
                -v $dir/conf.d:/etc/nginx/conf.d:ro          \
                -v $dir/ports.conf:/etc/nginx/ports.conf:ro  \
                -v $dir/www:/var/www:ro                      \
                -v $dir/logs:/var/log/nginx"
  dk_run
  probe_http "https://localhost/" 10 3
  log_success "Rolled back to $dir"
}

