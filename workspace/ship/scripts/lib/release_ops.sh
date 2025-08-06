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
RUNTIME_DIR="$WORKSPACE_ROOT/workspace/prep"
PORT_TPL_DIR="$WORKSPACE_ROOT/ports"
# shellcheck disable=SC2034
PROD_SSH="${PROD_SSH:-proxyuser@prod}"
PROD_ROOT="${PROD_ROOT:-/home/proxyuser/NgNix-RP}"

CNT_LOCAL=${CNT_LOCAL:-nginx-rp-local}
CNT_STAGE=${CNT_STAGE:-nginx-rp-stage}
CNT_PREPROD=${CNT_PREPROD:-nginx-rp-pre-prod}
CNT_PROD=${CNT_PROD:-nginx-rp-prod}

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

  CONTAINER_NAME="$CNT_LOCAL"
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
    stage)     CONTAINER_NAME="$CNT_STAGE"   ; cp "$PORT_TPL_DIR/stage.conf"   "$RUNTIME_DIR/ports.conf";;
    preprod)   CONTAINER_NAME="$CNT_PREPROD" ; cp "$PORT_TPL_DIR/preprod.conf" "$RUNTIME_DIR/ports.conf";;
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

  CONTAINER_NAME="$CNT_PROD"
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
  CONTAINER_NAME="$CNT_PROD"
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
# 7. rc_fetch_seed [dest] – fetch production snapshot to workspace
############################################################################
rc_fetch_seed() {
  local dest="${1:-$WORKSPACE_ROOT/workspace/seed}"
  require_cmd rsync
  
  # First try the legacy container name, then the new naming convention
  local container_name="${PROD_CONTAINER:-$CNT_PROD}"
  local src_dir=""
  
  # Try to get the runtime directory from container mounts
  local first_bind
  first_bind=$(ssh_cmd "docker inspect $container_name --format '{{ index .HostConfig.Binds 0 }}' 2>/dev/null" || echo "")
  
  if [[ -n "$first_bind" ]]; then
    # Extract the host path from the bind mount
    local host_path="${first_bind%%:*}"
    # If it's a file mount (like nginx.conf), get its directory
    if [[ "$host_path" == *".conf" ]] || [[ "$host_path" == *".json" ]]; then
      src_dir=$(dirname "$host_path")
    else
      # If it's a directory mount, check if it looks like a timestamped release
      local dir_name
      dir_name=$(basename "$host_path")
      if [[ "$dir_name" =~ ^Nginx-[0-9]{8}-[0-9]{6}$ ]]; then
        src_dir="$host_path"
      else
        # Legacy setup - use the parent directory
        src_dir="$host_path"
      fi
    fi
  fi
  
  # If we couldn't determine source directory, list available containers and let user choose
  if [[ -z "$src_dir" ]]; then
    log_warn "Container '$container_name' not found. Available containers:"
    local containers
    containers=$(ssh_cmd "docker ps --format '{{.Names}}'")
    
    if [[ -z "$containers" ]]; then
      log_error "No containers found on production server"
      die "No running containers available to clone from"
    fi
    
    echo "Available containers:"
    echo "$containers" | nl -w2 -s') '
    echo
    read -r -p "Select container number (or enter container name): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      container_name=$(echo "$containers" | sed -n "${choice}p")
    else
      container_name="$choice"
    fi
    
    [[ -n "$container_name" ]] || die "No container selected"
    log_info "Using container: $container_name"
    
    # Try again with selected container
    first_bind=$(ssh_cmd "docker inspect $container_name --format '{{ index .HostConfig.Binds 0 }}'" || echo "")
    if [[ -n "$first_bind" ]]; then
      local host_path="${first_bind%%:*}"
      if [[ "$host_path" == *".conf" ]] || [[ "$host_path" == *".json" ]]; then
        src_dir=$(dirname "$host_path")
      else
        src_dir="$host_path"
      fi
    fi
  fi
  
  [[ -n "$src_dir" ]] || die "Unable to determine prod runtime directory from container $container_name"
  
  log_info "Fetching production seed from $src_dir to $dest"
  mkdir -p "$dest"
  rsync -az "$PROD_SSH:$src_dir/" "$dest/"
  log_success "Production seed fetched to $dest"
}

############################################################################
# 8. rc_init_wip – initialize work-in-progress from seed
############################################################################
rc_init_wip() {
  local seed_dir="$WORKSPACE_ROOT/workspace/seed"
  local wip_dir="$WORKSPACE_ROOT/workspace/wip"
  
  if [[ ! -d "$seed_dir" ]]; then
    die "No seed found at $seed_dir. Run 'fetch-seed' first."
  fi
  
  log_info "Initializing WIP workspace from seed"
  mkdir -p "$wip_dir"
  
  # Copy seed to wip
  cp -r "$seed_dir"/* "$wip_dir/"
  
  log_success "WIP workspace initialized at $wip_dir"
}

############################################################################
# 9. rc_build_prep – build clean runtime from wip + new artifacts
############################################################################
rc_build_prep() {
  local wip_dir="$WORKSPACE_ROOT/workspace/wip"
  
  if [[ ! -d "$wip_dir" ]]; then
    log_warn "No WIP workspace found. Creating scaffold..."
    mkdir -p "$wip_dir/info_pages"
    mkdir -p "$wip_dir/certs"
    mkdir -p "$wip_dir/nginx-logs"
  fi
  
  # Generate local certs
  gen_dev_certs
  
  # Process any new artifacts from intake
  if [[ -d "$INTAKE_DIR" ]] && ls "$INTAKE_DIR"/*.zip >/dev/null 2>&1; then
    log_info "Processing new artifacts from $INTAKE_DIR"
    for zip in "$INTAKE_DIR"/*.zip; do
      log_info "Processing: $(basename "$zip")"
      # TODO: Extract and process zip files
    done
  fi
  
  # Build clean runtime from wip
  log_info "Building prep runtime from WIP workspace"
  rm -rf "$RUNTIME_DIR"
  mkdir -p "$RUNTIME_DIR"
  
  # Copy wip content to runtime
  cp -r "$wip_dir"/* "$RUNTIME_DIR/" 2>/dev/null || true
  
  # Ensure local certs are used
  cp "$WORKSPACE_ROOT/certs"/* "$RUNTIME_DIR/certs/" 2>/dev/null || true
  
  log_success "Prep runtime built at $RUNTIME_DIR"
}

############################################################################
# 10. rc_ensure_external_services – start stable external services
############################################################################
rc_ensure_external_services() {
  log_info "Ensuring external services are running"
  
  # Create network if it doesn't exist
  if ! docker network ls | grep -q pronunco-production; then
    log_info "Creating pronunco-production network"
    docker network create pronunco-production --subnet=172.20.0.0/16
  fi
  
  # Start vaultwarden-ship if not running
  if ! docker ps | grep -q vaultwarden-ship; then
    log_info "Starting vaultwarden-ship external service"
    
    # Stop if exists but not running
    docker stop vaultwarden-ship 2>/dev/null || true
    docker rm vaultwarden-ship 2>/dev/null || true
    
    # Create data directory
    mkdir -p "$WORKSPACE_ROOT/data/vaultwarden"
    
    docker run -d \
      --name vaultwarden-ship \
      --network pronunco-production \
      --ip 172.20.0.5 \
      -p 8223:80 \
      -v "$WORKSPACE_ROOT/data/vaultwarden:/data" \
      -e WEBSOCKET_ENABLED=true \
      vaultwarden/server:latest
    
    log_success "vaultwarden-ship started on port 8223"
  else
    log_info "vaultwarden-ship already running"
  fi
}

############################################################################
# 11. rc_start_seed – start production replica container (port 8080)
############################################################################
rc_start_seed() {
  local seed_dir="$WORKSPACE_ROOT/workspace/seed"
  
  if [[ ! -d "$seed_dir" ]]; then
    die "No seed found at $seed_dir. Run 'fetch-seed' first."
  fi
  
  local container_name="nginx-rp-seed"
  
  # Stop if already running
  docker stop "$container_name" 2>/dev/null || true
  docker rm "$container_name" 2>/dev/null || true
  
  log_info "Starting seed container (production replica) on port 8080"
  
  # Start container with production-like mounting but local ports
  docker run -d \
    --name "$container_name" \
    -p 8080:80 \
    -p 8443:443 \
    -v "$seed_dir/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -v "$seed_dir/certs:/etc/nginx/certs:ro" \
    -v "$seed_dir/info_pages:/var/www/info_pages:ro" \
    -v "$seed_dir/nginx-logs:/var/www/NgNix-RP/nginx-logs" \
    nginx:latest
  
  log_success "Seed container started: http://localhost:8080, https://localhost:8443"
}

############################################################################
# 11. rc_start_wip – start development container (port 8081)
############################################################################
rc_start_wip() {
  local wip_dir="$WORKSPACE_ROOT/workspace/wip"
  
  if [[ ! -d "$wip_dir" ]]; then
    die "No WIP workspace found at $wip_dir. Run 'init-wip' first."
  fi
  
  # Ensure external services are running
  rc_ensure_external_services
  
  local container_name="nginx-rp-wip"
  
  # Stop if already running
  docker stop "$container_name" 2>/dev/null || true
  docker rm "$container_name" 2>/dev/null || true
  
  log_info "Starting WIP container (development workspace) on port 8081"
  
  # Start container with both local and production certs, network access
  docker run -d \
    --name "$container_name" \
    --network pronunco-production \
    --ip 172.20.0.10 \
    -p 8081:80 \
    -p 8444:443 \
    -v "$wip_dir/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -v "$wip_dir/conf.d:/etc/nginx/conf.d:ro" \
    -v "$WORKSPACE_ROOT/certs:/etc/nginx/local-certs:ro" \
    -v "$WORKSPACE_ROOT/workspace/seed/certs:/etc/nginx/certs:ro" \
    -v "$wip_dir/info_pages:/var/www/info_pages:ro" \
    -v "$wip_dir/nginx-logs:/var/www/NgNix-RP/nginx-logs" \
    nginx:latest
  
  log_success "WIP container started: http://localhost:8081, https://localhost:8444"
}

############################################################################
# 12. rc_start_prep – start prep container (port 8082)
############################################################################
rc_start_prep() {
  if [[ ! -d "$RUNTIME_DIR" ]]; then
    die "No prep runtime found at $RUNTIME_DIR. Run 'build-prep' first."
  fi
  
  # Ensure external services are running
  rc_ensure_external_services
  
  local container_name="nginx-rp-prep"
  
  # Stop if already running
  docker stop "$container_name" 2>/dev/null || true
  docker rm "$container_name" 2>/dev/null || true
  
  log_info "Starting prep container (clean build) on port 8082"
  
  # Start container with runtime build, certificates and network access
  docker run -d \
    --name "$container_name" \
    --network pronunco-production \
    --ip 172.20.0.15 \
    -p 8082:80 \
    -p 8445:443 \
    -v "$RUNTIME_DIR/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -v "$RUNTIME_DIR/conf.d:/etc/nginx/conf.d:ro" \
    -v "$RUNTIME_DIR/certs:/etc/nginx/certs:ro" \
    -v "$WORKSPACE_ROOT/certs:/etc/nginx/local-certs:ro" \
    -v "$RUNTIME_DIR/info_pages:/var/www/info_pages:ro" \
    -v "$RUNTIME_DIR/nginx-logs:/var/www/NgNix-RP/nginx-logs" \
    nginx:latest
  
  log_success "Prep container started: http://localhost:8082, https://localhost:8445"
}

############################################################################
# 13. rc_init_stage – initialize stage environment (network + config updates)
############################################################################
rc_init_stage() {
  local stage_dir="${1:-$WORKSPACE_ROOT/workspace/ship}"
  
  if [[ ! -d "$stage_dir" ]]; then
    die "Stage directory not found at $stage_dir. Run 'start-ship' first."
  fi
  
  log_info "Initializing stage environment"
  
  # Create stage network if it doesn't exist
  if ! docker network ls | grep -q nginx-rp-network-stage; then
    log_info "Creating nginx-rp-network-stage network"
    docker network create nginx-rp-network-stage --subnet=172.21.0.0/16
  else
    log_info "nginx-rp-network-stage network already exists"
  fi
  
  # Update vaultwarden config for stage
  local vw_conf="$stage_dir/conf.d/vaultwarden.conf"
  if [[ -f "$vw_conf" ]]; then
    log_info "Updating vaultwarden config for stage environment"
    sed -i 's/vaultwarden-ship/vaultwarden-stage/g' "$vw_conf"
    log_info "Updated: vaultwarden-ship → vaultwarden-stage"
  fi
  
  log_success "Stage environment initialized"
  log_info "Network: nginx-rp-network-stage (172.21.0.0/16)"
  log_info "Ready to start stage containers with: start --env stage"
}

############################################################################
# 14. rc_start_ship – build ship from prep and start final verification
############################################################################
rc_start_ship() {
  if [[ ! -d "$RUNTIME_DIR" ]]; then
    die "No prep runtime found at $RUNTIME_DIR. Run 'build-prep' first."
  fi
  
  local ship_dir="$WORKSPACE_ROOT/workspace/ship"
  
  # Build ship from prep
  log_info "Building ship deployment package from prep runtime"
  rm -rf "$ship_dir"
  mkdir -p "$ship_dir"
  
  # Copy runtime configs
  cp -r "$RUNTIME_DIR"/* "$ship_dir/"
  
  # Copy deployment scripts and port configs
  cp -r "$WORKSPACE_ROOT/scripts" "$ship_dir/"
  cp -r "$WORKSPACE_ROOT/ports" "$ship_dir/"
  
  log_info "Ship package includes: runtime configs, deployment scripts, and port configs"
  
  # Ensure external services are running
  rc_ensure_external_services
  
  local container_name="nginx-rp-ship"
  
  # Stop if already running
  docker stop "$container_name" 2>/dev/null || true
  docker rm "$container_name" 2>/dev/null || true
  
  log_info "Starting ship container (final verification) on stage ports 8083/8446"
  
  # Start container with stage ports for final verification before IONOS deployment
  docker run -d \
    --name "$container_name" \
    --network pronunco-production \
    --ip 172.20.0.20 \
    -p 8083:80 \
    -p 8446:443 \
    -v "$ship_dir/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -v "$ship_dir/conf.d:/etc/nginx/conf.d:ro" \
    -v "$ship_dir/certs:/etc/nginx/certs:ro" \
    -v "$WORKSPACE_ROOT/certs:/etc/nginx/local-certs:ro" \
    -v "$ship_dir/info_pages:/var/www/info_pages:ro" \
    -v "$ship_dir/nginx-logs:/var/www/NgNix-RP/nginx-logs" \
    nginx:latest
  
  log_success "Ship container started: http://localhost:8083, https://localhost:8446"
  log_success "Ship runtime built at $ship_dir"
  log_info "🚢 Ready for IONOS deployment - copy $ship_dir/* to IONOS"
}

############################################################################
# 14. rc_stop_all – stop all local containers
############################################################################
rc_stop_all() {
  log_info "Stopping all local containers"
  
  for container in nginx-rp-seed nginx-rp-wip nginx-rp-prep nginx-rp-ship; do
    if docker ps -q -f name="$container" | grep -q .; then
      log_info "Stopping $container"
      docker stop "$container"
      docker rm "$container"
    else
      log_info "$container not running"
    fi
  done
  
  log_success "All local containers stopped"
}

