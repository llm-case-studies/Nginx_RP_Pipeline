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

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core.sh
source "$LIB_DIR/core.sh"
# shellcheck source=docker_ops.sh
source "$LIB_DIR/docker_ops.sh"
# shellcheck source=manifest_ops.sh
source "$LIB_DIR/manifest_ops.sh"

### CONFIG ----------------------------------------------------------------
WORKSPACE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
INTAKE_DIR="/mnt/pipeline-intake"         # absolute, shared by app teams
RUNTIME_DIR="$WORKSPACE_ROOT/runtime"
PORT_TPL_DIR="$WORKSPACE_ROOT/ports"
# shellcheck disable=SC2034
PROD_SSH="${PROD_SSH:-proxyuser@prod}"
PROD_ROOT="${PROD_ROOT:-/home/proxyuser/NgNix-RP}"

# These envs can be overridden by caller
IMAGE="${IMAGE:-nginx:latest}"
NETWORK_NAME="rp-net"

############################################################################
# 1. rc_build_local – build candidate & run local container
############################################################################
rc_build_local() {
  log_info "🛠  Building local candidate from $INTAKE_DIR"
  require_cmd unzip sha256sum jq
  gen_dev_certs

  [[ -d "$RUNTIME_DIR" ]] && rm -rf "$RUNTIME_DIR"
  mkdir -p "$RUNTIME_DIR/conf.d" "$RUNTIME_DIR/www" "$RUNTIME_DIR/logs" "$RUNTIME_DIR/info_pages"

  mapfile -t zips < <(find "$INTAKE_DIR" -maxdepth 1 -type f -name '*.zip')
  (( ${#zips[@]} > 0 )) || die "No artefacts in $INTAKE_DIR"

  apps_json="[]"
  for zip in "${zips[@]}"; do
    log_info "↳ Unpacking $(basename "$zip")"
    sha="$(sha256sum "$zip" | cut -d' ' -f1)"
    tmpdir=$(mktemp -d)
    unzip -q "$zip" -d "$tmpdir"
    if [[ -f "$tmpdir/nginx.conf" ]]; then
      mv "$tmpdir/nginx.conf" "$RUNTIME_DIR/nginx.conf"
    fi
    mv "$tmpdir"/*.conf "$RUNTIME_DIR/conf.d/" 2>/dev/null || true
    appname="$(basename "$zip" .zip)"
    if [[ -d "$tmpdir/dist" ]]; then
      mkdir -p "$RUNTIME_DIR/www/$appname"
      mv "$tmpdir/dist"/* "$RUNTIME_DIR/www/$appname/" || true
    fi
    commit=""
    if [[ -f "$tmpdir/VERSION.txt" ]]; then
      commit="$(head -n1 "$tmpdir/VERSION.txt")"
    fi
    apps_json=$(jq -c --arg name "$appname" \
                      --arg zip "$(basename "$zip")" \
                      --arg sha "$sha" \
                      --arg commit "$commit" \
                      '. + [{name:$name,zip:$zip,sha256:$sha,commit:$commit}]' <<< "$apps_json")
    rm -rf "$tmpdir"
  done

  cp "$PORT_TPL_DIR/local.conf" "$RUNTIME_DIR/ports.conf"
  cp "$WORKSPACE_ROOT/conf.d"/*.conf "$RUNTIME_DIR/conf.d/" 2>/dev/null || true
  [[ -f "$RUNTIME_DIR/nginx.conf" ]] || cp "$WORKSPACE_ROOT/conf/nginx.conf" "$RUNTIME_DIR/nginx.conf"

  local release_id="prod-$(now_ts)"
  manifest_write "$release_id" "${RELEASE_NOTE:-}" "$apps_json"

  log_success "Runtime candidate built at $RUNTIME_DIR"

  CONTAINER_NAME="rp-local"
  HTTP_PORT=8080 HTTPS_PORT=8443
  VOLUME_FLAGS="-v $RUNTIME_DIR/nginx.conf:/etc/nginx/nginx.conf:ro \
                -v $RUNTIME_DIR/conf.d:/etc/nginx/conf.d:ro          \
                -v $RUNTIME_DIR/ports.conf:/etc/nginx/ports.conf:ro  \
                -v $RUNTIME_DIR/www:/var/www:ro                      \
                -v $WORKSPACE_ROOT/certs:/etc/nginx/certs:ro         \
                -v $RUNTIME_DIR/logs:/var/www/NgNix-RP/nginx-logs    \
                -v $RUNTIME_DIR/info_pages:/var/www/info_pages:ro"
  EXTRA_DOCKER_OPTS="-e RELEASE_ID=$release_id"
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

  require_cmd jq
  release_id=$(jq -r '.id' "$RUNTIME_DIR/release.json")
  HTTP_PORT=80  HTTPS_PORT=443
  VOLUME_FLAGS="-v $RUNTIME_DIR/nginx.conf:/etc/nginx/nginx.conf:ro \
                -v $RUNTIME_DIR/conf.d:/etc/nginx/conf.d:ro          \
                -v $RUNTIME_DIR/ports.conf:/etc/nginx/ports.conf:ro  \
                -v $RUNTIME_DIR/www:/var/www:ro                      \
                -v $RUNTIME_DIR/logs:/var/www/NgNix-RP/nginx-logs    \
                -v $RUNTIME_DIR/info_pages:/var/www/info_pages:ro"
  EXTRA_DOCKER_OPTS="-e RELEASE_ID=$release_id"
  dk_run
  probe_http "https://localhost:443/" 5 2
}

############################################################################
# 3. rc_deploy_prod – promote to prod with timestamp dir
############################################################################
rc_deploy_prod() {
  require_cmd jq
  local release_id
  release_id=$(jq -r '.id' "$RUNTIME_DIR/release.json")
  local new_dir="$PROD_ROOT/Nginx-$release_id"

  log_info "🚀 Promoting runtime to $new_dir"
  cp -r "$RUNTIME_DIR" "$new_dir"

  CONTAINER_NAME="rp-prod"
  HTTP_PORT=80 HTTPS_PORT=443
  VOLUME_FLAGS="-v $new_dir/nginx.conf:/etc/nginx/nginx.conf:ro \
                -v $new_dir/conf.d:/etc/nginx/conf.d:ro          \
                -v $new_dir/ports.conf:/etc/nginx/ports.conf:ro  \
                -v $new_dir/www:/var/www:ro                      \
                -v $new_dir/logs:/var/www/NgNix-RP/nginx-logs    \
                -v $new_dir/info_pages:/var/www/info_pages:ro"
  EXTRA_DOCKER_OPTS="-e RELEASE_ID=$release_id"
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
  require_cmd jq
  local release_id
  release_id=$(jq -r '.id' "$dir/release.json" 2>/dev/null || echo '')
  CONTAINER_NAME="rp-prod"
  HTTP_PORT=80 HTTPS_PORT=443
  VOLUME_FLAGS="-v $dir/nginx.conf:/etc/nginx/nginx.conf:ro \
                -v $dir/conf.d:/etc/nginx/conf.d:ro          \
                -v $dir/ports.conf:/etc/nginx/ports.conf:ro  \
                -v $dir/www:/var/www:ro                      \
                -v $dir/logs:/var/www/NgNix-RP/nginx-logs    \
                -v $dir/info_pages:/var/www/info_pages:ro"
  EXTRA_DOCKER_OPTS="-e RELEASE_ID=$release_id"
  dk_run
  probe_http "https://localhost/" 10 3
  log_success "Rolled back to $dir"
}

############################################################################
# 5. rc_list_releases – list prod releases with manifest note
############################################################################
rc_list_releases() {
  require_cmd jq
  mapfile -t dirs < <(find "$PROD_ROOT" -maxdepth 1 -type d -name 'Nginx-prod-*' | sort)
  for dir in "${dirs[@]}"; do
    local id="${dir##*/Nginx-}"
    local note=""
    [[ -f "$dir/release.json" ]] && note=$(jq -r '.note' "$dir/release.json")
    printf '%s\t%s\n' "$id" "$note"
  done
}

############################################################################
# 6. rc_describe_release <dir> – pretty-print manifest
############################################################################
rc_describe_release() {
  local dir="$1"
  [[ -n "$dir" ]] || die "Usage: rc_describe_release <dir>"
  [[ -f "$dir/release.json" ]] || die "release.json not found in $dir"
  manifest_pretty "$dir/release.json"
}

############################################################################
# 7. rc_clone_prod [dest] – copy current prod runtime
############################################################################
rc_clone_prod() {
  local dest="${1:-$RUNTIME_DIR/prod-clone}"
  require_cmd rsync
  local ts
  ts=$(ssh_cmd "docker inspect rp-prod --format '{{ index .HostConfig.Binds 0 }}'" \
        | xargs dirname | awk -F'/' '{print $NF}')
  [[ -n "$ts" ]] || die "Unable to determine prod runtime directory"
  local src="$PROD_ROOT/$ts"
  log_info "Cloning prod runtime from $src to $dest"
  mkdir -p "$dest"
  rsync -az "$PROD_SSH:$src/" "$dest/"
  log_success "Prod runtime cloned to $dest"
}

