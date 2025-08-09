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
# shellcheck source=config_loader.sh
source "$LIB_DIR/config_loader.sh"

### CONFIG ----------------------------------------------------------------
WORKSPACE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
INTAKE_DIR="/mnt/pipeline-intake"         # absolute, shared by app teams
RUNTIME_DIR="$WORKSPACE_ROOT/workspace/prep"
PORT_TPL_DIR="$WORKSPACE_ROOT/ports"

# Legacy SSH configuration (will be replaced by DEPLOYMENT_SSH)
# shellcheck disable=SC2034
PROD_SSH="${PROD_SSH:-proxyuser@prod}"
PROD_ROOT="${PROD_ROOT:-/home/proxyuser/NgNix-RP}"

# Legacy container names (will be replaced by deterministic naming)
CNT_LOCAL=${CNT_LOCAL:-nginx-rp-local}
CNT_STAGE=${CNT_STAGE:-nginx-rp-stage}
CNT_PREPROD=${CNT_PREPROD:-nginx-rp-pre-prod}
CNT_PROD=${CNT_PROD:-nginx-rp-prod}

# Docker image configuration
IMAGE="${IMAGE:-nginx:latest}"

# Default network name (will be overridden by environment configs)
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
  
  # Check if WIP is locked
  if rc_check_wip_lock; then
    log_error "❌ WIP workspace is locked and cannot be reinitialized"
    local lock_file="$wip_dir/.lock"
    local reason
    reason=$(jq -r '.reason // "No reason specified"' "$lock_file" 2>/dev/null || echo "Lock file corrupted")
    log_error "   Reason: $reason"
    log_error "   Use 'unlock-wip' first if you want to reinitialize"
    log_error "   WARNING: This will lose all manual changes in WIP workspace!"
    exit 1
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
  
  # SANITY CHECK: Verify WIP workspace exists and is complete
  log_info "🔍 Validating WIP workspace before building prep..."
  
  if [[ ! -d "$wip_dir" ]]; then
    log_error "❌ WIP workspace not found at $wip_dir"
    log_error "   Run 'build-wip' first to create integration workspace"
    exit 1
  fi
  
  # Check if WIP is locked
  if [[ -f "$wip_dir/.lock" ]]; then
    log_info "🔒 WIP workspace is locked (contains manual fixes)"
    local lock_info
    lock_info=$(cat "$wip_dir/.lock" 2>/dev/null || echo '{}')
    local reason
    reason=$(echo "$lock_info" | jq -r '.reason // "No reason specified"' 2>/dev/null || echo "Lock file corrupted")
    log_info "   Reason: $reason"
    log_info "   Proceeding with locked state (preserving manual changes)"
  fi
  
  # Validate WIP completeness
  local validation_failed=false
  
  # Check essential directories
  for dir in conf.d info_pages certs; do
    if [[ ! -d "$wip_dir/$dir" ]]; then
      log_error "❌ Missing critical directory in WIP: $dir"
      validation_failed=true
    else
      log_info "   ✅ WIP directory present: $dir"
    fi
  done
  
  # Check essential files  
  if [[ ! -f "$wip_dir/nginx.conf" ]]; then
    log_error "❌ Missing nginx.conf in WIP workspace"
    validation_failed=true
  else
    log_info "   ✅ WIP nginx.conf present"
  fi
  
  # Verify certificates exist
  if [[ -d "$wip_dir/certs" ]]; then
    local cert_count
    cert_count=$(find "$wip_dir/certs" -name "*.cer" -o -name "*.pem" -o -name "*.key" 2>/dev/null | wc -l)
    if [[ $cert_count -eq 0 ]]; then
      log_error "❌ No certificate files found in WIP certs directory"
      log_error "   WIP should contain production certs (from seed) + new app certs"
      validation_failed=true
    else
      log_info "   ✅ Found $cert_count certificate files in WIP"
    fi
  fi
  
  # Check nginx configuration syntax if nginx available
  if command -v nginx >/dev/null 2>&1; then
    log_info "   🔍 Testing WIP nginx configuration syntax..."
    if nginx -t -c "$wip_dir/nginx.conf" -p "$wip_dir" >/dev/null 2>&1; then
      log_info "   ✅ WIP nginx configuration syntax valid"
    else
      log_error "❌ WIP nginx configuration syntax invalid"
      nginx -t -c "$wip_dir/nginx.conf" -p "$wip_dir" 2>&1 | head -3
      validation_failed=true
    fi
  fi
  
  if [[ "$validation_failed" == "true" ]]; then
    log_error "🚨 WIP VALIDATION FAILED!"
    log_error "   Cannot build prep from incomplete WIP workspace"
    log_error "   Fix WIP issues first, then retry build-prep"
    exit 1
  fi
  
  log_success "✅ WIP validation passed - ready to build prep"
  
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
# 12.5. rc_build_ship – build self-contained deployment package with generated scripts
############################################################################
rc_build_ship() {
  # SANITY CHECK: Verify prep runtime exists and is complete
  log_info "🔍 Validating prep runtime before building ship..."
  
  if [[ ! -d "$RUNTIME_DIR" ]]; then
    log_error "❌ Prep runtime not found at $RUNTIME_DIR"
    log_error "   Run 'build-prep' first to create clean runtime"
    exit 1
  fi
  
  # Validate prep runtime completeness  
  local validation_failed=false
  
  # Check essential directories
  for dir in conf.d info_pages certs; do
    if [[ ! -d "$RUNTIME_DIR/$dir" ]]; then
      log_error "❌ Missing critical directory in prep runtime: $dir"
      validation_failed=true
    else
      log_info "   ✅ Prep directory present: $dir"
    fi
  done
  
  # Check essential files
  if [[ ! -f "$RUNTIME_DIR/nginx.conf" ]]; then
    log_error "❌ Missing nginx.conf in prep runtime"
    validation_failed=true
  else
    log_info "   ✅ Prep nginx.conf present"
  fi
  
  # Verify certificates exist
  if [[ -d "$RUNTIME_DIR/certs" ]]; then
    local cert_count
    cert_count=$(find "$RUNTIME_DIR/certs" -name "*.cer" -o -name "*.pem" -o -name "*.key" 2>/dev/null | wc -l)
    if [[ $cert_count -eq 0 ]]; then
      log_error "❌ No certificate files found in prep runtime certs directory"
      log_error "   Prep runtime should contain clean certificate set from WIP"
      validation_failed=true
    else
      log_info "   ✅ Found $cert_count certificate files in prep runtime"
    fi
  fi
  
  # Check nginx configuration syntax
  if command -v nginx >/dev/null 2>&1; then
    log_info "   🔍 Testing prep nginx configuration syntax..."
    if nginx -t -c "$RUNTIME_DIR/nginx.conf" -p "$RUNTIME_DIR" >/dev/null 2>&1; then
      log_info "   ✅ Prep nginx configuration syntax valid"
    else
      log_error "❌ Prep nginx configuration syntax invalid"
      nginx -t -c "$RUNTIME_DIR/nginx.conf" -p "$RUNTIME_DIR" 2>&1 | head -3
      validation_failed=true
    fi
  fi
  
  if [[ "$validation_failed" == "true" ]]; then
    log_error "🚨 PREP RUNTIME VALIDATION FAILED!"
    log_error "   Cannot build ship from incomplete prep runtime" 
    log_error "   Fix prep runtime issues first, then retry build-ship"
    exit 1
  fi
  
  log_success "✅ Prep runtime validation passed - ready to build ship"

  local ship_dir="$WORKSPACE_ROOT/workspace/ship"
  log_info "🚢 Building self-contained ship deployment package"
  
  # Create clean ship directory
  rm -rf "$ship_dir"
  mkdir -p "$ship_dir"
  
  # Copy prep runtime (the clean build)
  cp -r "$RUNTIME_DIR"/* "$ship_dir/"
  
  # Copy core scripts (but not full environments tree)
  cp -r "$WORKSPACE_ROOT/scripts" "$ship_dir/"
  
  # Generate environment-specific deployment scripts
  log_info "Generating deployment scripts for Type-5 environments"
  
  for env in ship stage preprod prod; do
    generate_deployment_script "$env" "$ship_dir"
  done
  
  # Create README for deployment
  cat > "$ship_dir/README.md" << 'EOF'
# Self-Contained Deployment Package

This package contains everything needed to deploy to any Type-5 environment.

## Usage

### Local Ship Environment (testing)
```bash
./start-ship.sh
```

### Stage Environment (IONOS staging)
```bash
./start-stage.sh
```

### Pre-production Environment
```bash
./start-preprod.sh
```

### Production Environment
```bash
./start-prod.sh
```

## What's Included

- Runtime configurations (nginx.conf, conf.d/*)
- SSL certificates
- Info pages
- Environment-specific deployment scripts
- Zero-entropy deterministic deployment

## Adding New Services

1. Add service configuration to `conf.d/servicename.conf`
2. Add SSL certificates to `certs/domain.com/`
3. Add info pages to `info_pages/domain.com/`
4. Deployment scripts automatically discover and configure new services

No script modifications needed!
EOF

  # CRITICAL: Verify ship package completeness before declaring success
  log_info "🔍 Verifying ship package completeness..."
  
  local verification_failed=false
  
  # Check essential directories exist
  for dir in certs conf.d info_pages scripts; do
    if [[ ! -d "$ship_dir/$dir" ]]; then
      log_error "❌ Missing critical directory: $dir"
      verification_failed=true
    else
      log_info "   ✅ Directory present: $dir"
    fi
  done
  
  # Check essential files exist
  for file in nginx.conf README.md; do
    if [[ ! -f "$ship_dir/$file" ]]; then
      log_error "❌ Missing critical file: $file"
      verification_failed=true
    else
      log_info "   ✅ File present: $file"
    fi
  done
  
  # Verify certificates are present
  if [[ -d "$ship_dir/certs" ]]; then
    local cert_count=$(find "$ship_dir/certs" -name "*.cer" -o -name "*.pem" -o -name "*.key" | wc -l)
    if [[ $cert_count -eq 0 ]]; then
      log_error "❌ No certificate files found in certs/ directory"
      verification_failed=true
    else
      log_info "   ✅ Found $cert_count certificate files"
    fi
  fi
  
  # Check nginx config syntax
  if command -v nginx >/dev/null 2>&1; then
    log_info "   🔍 Testing nginx configuration syntax..."
    if nginx -t -c "$ship_dir/nginx.conf" -p "$ship_dir" >/dev/null 2>&1; then
      log_info "   ✅ Nginx configuration syntax valid"
    else
      log_error "❌ Nginx configuration syntax invalid"
      nginx -t -c "$ship_dir/nginx.conf" -p "$ship_dir" 2>&1 | head -5
      verification_failed=true
    fi
  else
    log_warn "   ⚠️ nginx not available for syntax checking"
  fi
  
  # Verify deployment scripts were generated
  for env in ship stage preprod prod; do
    if [[ ! -f "$ship_dir/start-${env}.sh" ]]; then
      log_error "❌ Missing deployment script: start-${env}.sh"
      verification_failed=true
    elif [[ ! -x "$ship_dir/start-${env}.sh" ]]; then
      log_error "❌ Deployment script not executable: start-${env}.sh"
      verification_failed=true
    else
      log_info "   ✅ Deployment script ready: start-${env}.sh"
    fi
  done
  
  if [[ "$verification_failed" == "true" ]]; then
    log_error "🚨 SHIP PACKAGE VERIFICATION FAILED!"
    log_error "   Package is incomplete and MUST NOT be deployed"
    log_error "   Fix the issues above and rebuild"
    exit 1
  fi
  
  log_success "✅ Ship package verification passed - ready for deployment"
  log_info "   Self-contained deployment scripts generated"
  log_info "   Ready for: ship, stage, preprod, prod environments"
  log_info "🚢 Copy $ship_dir/* to deployment target and run ./start-<env>.sh"
}

# Generate deployment script for specific environment
generate_deployment_script() {
  local env="$1"
  local ship_dir="$2"
  local script_file="$ship_dir/start-${env}.sh"
  
  # Set defaults before loading environment configuration
  DEPLOYMENT_ROOT="/opt/nginx-rp"
  ENVIRONMENT="$env"
  
  # Load and calculate deterministic values
  source "$WORKSPACE_ROOT/environments/base/calculate_deterministic_values.sh"
  calculate_deterministic_values
  
  log_info "  → Generating start-${env}.sh"
  
  cat > "$script_file" << EOF
#!/usr/bin/env bash
#-------------------------------------------------------------
# start-${env}.sh - Self-contained ${env} environment deployment
# Generated by build-ship - DO NOT EDIT MANUALLY
#-------------------------------------------------------------
set -euo pipefail

# Environment Configuration (Type-5: Zero Entropy)
ENVIRONMENT="$ENVIRONMENT"
DEPLOYMENT_ROOT="\$(pwd)"
NETWORK_NAME="$NETWORK_NAME"
CONTAINER_NAME="$CONTAINER_NAME"
VAULTWARDEN_NAME="$VAULTWARDEN_NAME"

# Port Configuration
HTTP_PORT=$HTTP_PORT
HTTPS_PORT=$HTTPS_PORT
VAULTWARDEN_PORT=$VAULTWARDEN_PORT

# Network Configuration  
NETWORK_SUBNET="$NETWORK_SUBNET"
NGINX_IP="$NGINX_IP"
VAULTWARDEN_IP="$VAULTWARDEN_IP"

# Docker Image
IMAGE="nginx:latest"

echo "🚀 Starting \$ENVIRONMENT environment"
echo "   Container: \$CONTAINER_NAME"
echo "   Network: \$NETWORK_NAME (\$NETWORK_SUBNET)"
echo "   Ports: HTTP=\$HTTP_PORT, HTTPS=\$HTTPS_PORT"

# Create deterministic network if it doesn't exist
if ! docker network ls | grep -q "\$NETWORK_NAME"; then
  echo "Creating network: \$NETWORK_NAME (\$NETWORK_SUBNET)"
  docker network create "\$NETWORK_NAME" --subnet="\$NETWORK_SUBNET"
else
  echo "Network \$NETWORK_NAME already exists"
fi

# Auto-discover and start services from conf.d
echo "Auto-discovering services from conf.d/*.conf files"
for conf_file in "\$DEPLOYMENT_ROOT/conf.d"/*.conf; do
  [[ -f "\$conf_file" ]] || continue
  
  service_name=\$(basename "\$conf_file" .conf)
  service_container="\${service_name}-\${ENVIRONMENT}"
  
  # Extract upstream references to start dependent services
  if grep -q "proxy_pass.*\${service_name}-" "\$conf_file"; then
    echo "  → Found service: \$service_name"
    
    # Start service container if not running
    if ! docker ps | grep -q "\$service_container"; then
      echo "    Starting \$service_container"
      
      docker stop "\$service_container" 2>/dev/null || true
      docker rm "\$service_container" 2>/dev/null || true
      
      # Create service-specific data directory
      mkdir -p "./data/\$service_name-\$ENVIRONMENT"
      
      # Determine service port (auto-increment from base)
      case "\$service_name" in
        vaultwarden) service_port=\$VAULTWARDEN_PORT ;;
        *) service_port=\$((VAULTWARDEN_PORT + 100)) ;;  # Auto-assign ports
      esac
      
      # Start service container
      docker run -d \\
        --name "\$service_container" \\
        --network "\$NETWORK_NAME" \\
        --ip "\$VAULTWARDEN_IP" \\
        -p "\$service_port:80" \\
        -v "\$(pwd)/data/\$service_name-\$ENVIRONMENT:/data" \\
        -e WEBSOCKET_ENABLED=true \\
        \${service_name}/server:latest 2>/dev/null || \\
      docker run -d \\
        --name "\$service_container" \\
        --network "\$NETWORK_NAME" \\
        --ip "\$VAULTWARDEN_IP" \\
        -p "\$service_port:80" \\
        -v "\$(pwd)/data/\$service_name-\$ENVIRONMENT:/data" \\
        nginx:latest
        
      echo "    ✅ \$service_container started on port \$service_port"
    else
      echo "    \$service_container already running"
    fi
    
    # Update service references in nginx config
    sed -i "s/\$service_name-ship:/\$service_container:/g" "\$DEPLOYMENT_ROOT/conf.d/\$service_name.conf"
    sed -i "s/\$service_name-[a-zA-Z]*:/\$service_container:/g" "\$DEPLOYMENT_ROOT/conf.d/\$service_name.conf"
  fi
done

# Stop nginx container if already running
docker stop "\$CONTAINER_NAME" 2>/dev/null || true
docker rm "\$CONTAINER_NAME" 2>/dev/null || true

echo "Starting \$CONTAINER_NAME on \$NETWORK_NAME network"

# Start nginx container
docker run -d \\
  --name "\$CONTAINER_NAME" \\
  --network "\$NETWORK_NAME" \\
  --ip "\$NGINX_IP" \\
  -p "\$HTTP_PORT:80" \\
  -p "\$HTTPS_PORT:443" \\
  -v "\$DEPLOYMENT_ROOT/nginx.conf:/etc/nginx/nginx.conf:ro" \\
  -v "\$DEPLOYMENT_ROOT/conf.d:/etc/nginx/conf.d:ro" \\
  -v "\$DEPLOYMENT_ROOT/certs:/etc/nginx/certs:ro" \\
  -v "\$DEPLOYMENT_ROOT/info_pages:/var/www/info_pages:ro" \\
  -v "\$DEPLOYMENT_ROOT/nginx-logs:/var/www/NgNix-RP/nginx-logs" \\
  "\$IMAGE"

echo "✅ \$ENVIRONMENT environment started successfully!"
echo "   URLs: http://localhost:\$HTTP_PORT, https://localhost:\$HTTPS_PORT"
echo "   Logs: docker logs \$CONTAINER_NAME"

# Test nginx configuration
sleep 2
if docker ps | grep -q "\$CONTAINER_NAME"; then
  echo "✅ \$CONTAINER_NAME is running"
  docker logs "\$CONTAINER_NAME" --tail 5 2>/dev/null || true
else
  echo "❌ \$CONTAINER_NAME failed to start"
  docker logs "\$CONTAINER_NAME" 2>/dev/null || true
  exit 1
fi
EOF

  chmod +x "$script_file"
}

############################################################################
# WIP Locking Mechanism - Protect manual integration fixes
############################################################################

# Lock WIP workspace to prevent overwriting manual changes
rc_lock_wip() {
  local reason="${1:-Manual integration fixes applied}"
  local wip_dir="$WORKSPACE_ROOT/workspace/wip"
  local lock_file="$wip_dir/.lock"
  
  if [[ ! -d "$wip_dir" ]]; then
    log_error "❌ WIP workspace not found at $wip_dir"
    log_error "   Nothing to lock - create WIP workspace first"
    exit 1
  fi
  
  if [[ -f "$lock_file" ]]; then
    log_warn "⚠️ WIP workspace is already locked"
    local existing_reason
    existing_reason=$(jq -r '.reason // "No reason specified"' "$lock_file" 2>/dev/null || echo "Lock file corrupted")
    log_info "   Existing reason: $existing_reason"
    log_info "   Use 'unlock-wip' first if you want to change the lock"
    return 0
  fi
  
  # Detect modified files since last build
  local modified_files=()
  if [[ -d "$WORKSPACE_ROOT/workspace/seed" ]]; then
    log_info "🔍 Detecting changes since seed..."
    while IFS= read -r -d '' file; do
      local rel_path="${file#$wip_dir/}"
      modified_files+=("$rel_path")
    done < <(find "$wip_dir" -type f -newer "$WORKSPACE_ROOT/workspace/seed" -print0 2>/dev/null || true)
  fi
  
  # Create lock file with metadata
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local user
  user=$(whoami)
  
  cat > "$lock_file" << EOF
{
  "locked_at": "$timestamp",
  "locked_by": "$user",
  "reason": "$reason",
  "modified_files": $(printf '%s\n' "${modified_files[@]}" | jq -R . | jq -s .),
  "wip_state_hash": "$(find "$wip_dir" -type f -exec md5sum {} \; 2>/dev/null | md5sum | cut -d' ' -f1)"
}
EOF
  
  log_success "🔒 WIP workspace locked successfully"
  log_info "   Reason: $reason" 
  log_info "   Protected files: ${#modified_files[@]} detected changes"
  log_info "   Use 'unlock-wip' when ready to allow modifications"
}

# Unlock WIP workspace to allow modifications
rc_unlock_wip() {
  local wip_dir="$WORKSPACE_ROOT/workspace/wip"
  local lock_file="$wip_dir/.lock"
  
  if [[ ! -f "$lock_file" ]]; then
    log_info "ℹ️ WIP workspace is not locked"
    return 0
  fi
  
  # Show lock info before unlocking
  local lock_info
  lock_info=$(cat "$lock_file" 2>/dev/null || echo '{}')
  local locked_at
  locked_at=$(echo "$lock_info" | jq -r '.locked_at // "Unknown"' 2>/dev/null || echo "Unknown")
  local reason
  reason=$(echo "$lock_info" | jq -r '.reason // "No reason specified"' 2>/dev/null || echo "Lock file corrupted")
  
  log_info "🔓 Unlocking WIP workspace"
  log_info "   Previously locked at: $locked_at"
  log_info "   Reason: $reason"
  
  rm -f "$lock_file"
  log_success "✅ WIP workspace unlocked - modifications now allowed"
}

# Check if WIP workspace is locked (for use in other functions)
rc_check_wip_lock() {
  local wip_dir="$WORKSPACE_ROOT/workspace/wip"
  local lock_file="$wip_dir/.lock"
  
  if [[ -f "$lock_file" ]]; then
    return 0  # Locked
  else
    return 1  # Not locked
  fi
}

# Show WIP lock status and details
rc_wip_status() {
  local wip_dir="$WORKSPACE_ROOT/workspace/wip"
  local lock_file="$wip_dir/.lock"
  
  if [[ ! -d "$wip_dir" ]]; then
    log_info "📁 WIP workspace: Not found"
    return 0
  fi
  
  if [[ ! -f "$lock_file" ]]; then
    log_info "📁 WIP workspace: Unlocked (modifications allowed)"
    return 0
  fi
  
  log_info "📁 WIP workspace: Locked 🔒"
  local lock_info
  lock_info=$(cat "$lock_file" 2>/dev/null || echo '{}')
  
  local locked_at
  locked_at=$(echo "$lock_info" | jq -r '.locked_at // "Unknown"' 2>/dev/null || echo "Unknown")
  local locked_by  
  locked_by=$(echo "$lock_info" | jq -r '.locked_by // "Unknown"' 2>/dev/null || echo "Unknown")
  local reason
  reason=$(echo "$lock_info" | jq -r '.reason // "No reason specified"' 2>/dev/null || echo "Lock file corrupted")
  
  log_info "   Locked at: $locked_at"
  log_info "   Locked by: $locked_by"
  log_info "   Reason: $reason"
  
  # Show modified files if available
  local modified_files
  modified_files=$(echo "$lock_info" | jq -r '.modified_files[]?' 2>/dev/null)
  if [[ -n "$modified_files" ]]; then
    log_info "   Protected changes:"
    echo "$modified_files" | head -5 | sed 's/^/     - /'
    local total_files
    total_files=$(echo "$modified_files" | wc -l)
    if [[ $total_files -gt 5 ]]; then
      log_info "     ... and $((total_files - 5)) more files"
    fi
  fi
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
  
  # Load ship environment configuration (Type-5)
  load_environment_config "ship"
  
  # Build ship from prep  
  log_info "Building ship deployment package from prep runtime"
  rm -rf "$DEPLOYMENT_ROOT"
  mkdir -p "$DEPLOYMENT_ROOT"
  
  # Copy runtime configs
  cp -r "$RUNTIME_DIR"/* "$DEPLOYMENT_ROOT/"
  
  # Copy deployment scripts and port configs
  cp -r "$WORKSPACE_ROOT/scripts" "$DEPLOYMENT_ROOT/"
  cp -r "$WORKSPACE_ROOT/ports" "$DEPLOYMENT_ROOT/"
  
  log_info "Ship package includes: runtime configs, deployment scripts, and port configs"
  
  # Ensure external services are running
  rc_ensure_external_services
  
  # Stop if already running
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  
  log_info "Starting $CONTAINER_NAME container (final verification) on ports $HTTP_PORT/$HTTPS_PORT"
  
  # Use legacy network for backward compatibility with existing services
  local network_to_use="${LEGACY_NETWORK:-$NETWORK_NAME}"
  
  # Start container with deterministic configuration
  docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$network_to_use" \
    --ip "$NGINX_IP" \
    -p "$HTTP_PORT:80" \
    -p "$HTTPS_PORT:443" \
    -v "$DEPLOYMENT_ROOT/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -v "$DEPLOYMENT_ROOT/conf.d:/etc/nginx/conf.d:ro" \
    -v "$DEPLOYMENT_ROOT/certs:/etc/nginx/certs:ro" \
    -v "$WORKSPACE_ROOT/certs:/etc/nginx/local-certs:ro" \
    -v "$DEPLOYMENT_ROOT/info_pages:/var/www/info_pages:ro" \
    -v "$DEPLOYMENT_ROOT/nginx-logs:/var/www/NgNix-RP/nginx-logs" \
    "$IMAGE"
  
  log_success "$CONTAINER_NAME started: http://localhost:$HTTP_PORT, https://localhost:$HTTPS_PORT"
  log_success "Ship runtime built at $DEPLOYMENT_ROOT"
  log_info "🚢 Ready for IONOS deployment - copy $DEPLOYMENT_ROOT/* to IONOS"
}

############################################################################
# 15. rc_start_environment – start any Type-5 environment using deterministic config
############################################################################
rc_start_environment() {
  local env="${1:-ship}"
  local runtime_source="${2:-$RUNTIME_DIR}"
  
  if [[ ! -d "$runtime_source" ]]; then
    die "Runtime source not found at $runtime_source"
  fi
  
  # Load environment configuration (Type-5)
  load_environment_config "$env"
  
  log_info "🚀 Starting $env environment using deterministic configuration"
  
  # Ensure deployment directory exists
  mkdir -p "$DEPLOYMENT_ROOT"
  
  # Copy runtime to deployment location (if not already there)
  if [[ "$runtime_source" != "$DEPLOYMENT_ROOT" ]]; then
    log_info "Copying runtime from $runtime_source to $DEPLOYMENT_ROOT"
    cp -r "$runtime_source"/* "$DEPLOYMENT_ROOT/"
  fi
  
  # Create deterministic network if it doesn't exist  
  if ! docker network ls | grep -q "$NETWORK_NAME"; then
    log_info "Creating network: $NETWORK_NAME ($NETWORK_SUBNET)"
    docker network create "$NETWORK_NAME" --subnet="$NETWORK_SUBNET"
  fi
  
  # Start vaultwarden service for this environment
  if ! docker ps | grep -q "$VAULTWARDEN_NAME"; then
    log_info "Starting $VAULTWARDEN_NAME service"
    
    docker stop "$VAULTWARDEN_NAME" 2>/dev/null || true
    docker rm "$VAULTWARDEN_NAME" 2>/dev/null || true
    
    mkdir -p "$WORKSPACE_ROOT/data/vaultwarden-$ENVIRONMENT"
    
    docker run -d \
      --name "$VAULTWARDEN_NAME" \
      --network "$NETWORK_NAME" \
      --ip "$VAULTWARDEN_IP" \
      -p "$VAULTWARDEN_PORT:80" \
      -v "$WORKSPACE_ROOT/data/vaultwarden-$ENVIRONMENT:/data" \
      -e WEBSOCKET_ENABLED=true \
      vaultwarden/server:latest
  fi
  
  # Stop nginx container if already running
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  
  log_info "Starting $CONTAINER_NAME on $NETWORK_NAME network"
  
  # Start nginx container with deterministic configuration
  docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    --ip "$NGINX_IP" \
    -p "$HTTP_PORT:80" \
    -p "$HTTPS_PORT:443" \
    -v "$DEPLOYMENT_ROOT/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -v "$DEPLOYMENT_ROOT/conf.d:/etc/nginx/conf.d:ro" \
    -v "$DEPLOYMENT_ROOT/certs:/etc/nginx/certs:ro" \
    -v "$WORKSPACE_ROOT/certs:/etc/nginx/local-certs:ro" \
    -v "$DEPLOYMENT_ROOT/info_pages:/var/www/info_pages:ro" \
    -v "$DEPLOYMENT_ROOT/nginx-logs:/var/www/NgNix-RP/nginx-logs" \
    "$IMAGE"
  
  log_success "✅ $env environment started successfully!"
  log_info "   Container: $CONTAINER_NAME"
  log_info "   Network: $NETWORK_NAME ($NETWORK_SUBNET)"
  log_info "   URLs: http://localhost:$HTTP_PORT, https://localhost:$HTTPS_PORT"
  log_info "   Vaultwarden: $VAULTWARDEN_NAME"
}

############################################################################
# 16. rc_stop_all – stop all local containers
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

