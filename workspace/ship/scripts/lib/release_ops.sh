#!/usr/bin/env bash
# release_ops.sh - Core release operations and workflow orchestration
# Refactored to use modular components for better maintainability

set -euo pipefail

# Source required modules
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/validation.sh"
source "$LIB_DIR/wip_management.sh"  
source "$LIB_DIR/deployment_generation.sh"
source "$LIB_DIR/environment_ops.sh"

############################################################################
# Core Release Operations - High-level workflow orchestration
############################################################################

# Build local development environment
rc_build_local() {
  log_info "Building local development environment"
  
  # Ensure external services are running first
  ensure_external_services
  
  # Create basic workspace structure if it doesn't exist
  mkdir -p "$WORKSPACE_ROOT/workspace/"{seed,wip,prep,ship}
  mkdir -p "$RUNTIME_DIR"
  
  log_success "Local development environment ready"
}

# Start an environment based on parameters
rc_start() {
  local env="${1:-wip}"
  local port="${2:-8081}"
  
  case "$env" in
    seed) start_seed_environment ;;
    wip) start_wip_environment ;;
    prep) start_prep_environment ;;
    ship) start_ship_environment ;;
    *) 
      log_error "Unknown environment: $env"
      log_info "Available: seed, wip, prep, ship"
      return 1
      ;;
  esac
}

# Deploy to production (placeholder for future implementation)
rc_deploy_prod() {
  log_info "Production deployment"
  log_warn "Production deployment not yet implemented"
  log_info "Use ship package and run ./start-prod.sh on target server"
}

# Rollback to previous release (placeholder for future implementation)  
rc_rollback() {
  log_info "Rolling back to previous release"
  log_warn "Rollback functionality not yet implemented"
}

# List available releases (placeholder for future implementation)
rc_list_releases() {
  log_info "Available releases:"
  log_warn "Release listing not yet implemented"
}

# Describe a specific release (placeholder for future implementation)
rc_describe_release() {
  local release_dir="${1:-}"
  if [[ -z "$release_dir" ]]; then
    log_error "Usage: describe-release <release-directory>"
    return 1
  fi
  
  log_info "Describing release: $release_dir"
  log_warn "Release description not yet implemented"
}

############################################################################
# Core Pipeline Operations - seed → wip → prep → ship
############################################################################

# Fetch production snapshot to seed workspace
rc_fetch_seed() {
  local dest="${1:-${WORKSPACE_ROOT:-}/workspace/seed}"
  require_cmd rsync
  
  log_info "Fetching production snapshot to seed workspace"
  
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
    ssh_cmd "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'" || true
    log_error "Update PROD_CONTAINER in deploy.conf or verify container is running"
    return 1
  fi
  
  log_info "Fetching from: $PROD_SSH:$src_dir"
  log_info "Destination: $dest"
  
  # Create destination directory
  mkdir -p "$dest"
  
  # Sync production state
  rsync -avz --delete \
    -e "ssh -o StrictHostKeyChecking=no" \
    "$PROD_SSH:$src_dir/" "$dest/" || {
    log_error "Failed to sync from production"
    return 1
  }
  
  # Validate what we received
  validate_seed_workspace "$dest"
  
  log_success "Production snapshot fetched to $dest"
}

# Initialize work-in-progress workspace from seed
rc_init_wip() {
  # Use relative paths from project root
  local project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  local seed_dir="$project_root/workspace/seed"
  local wip_dir="$project_root/workspace/wip"
  
  # Validate seed workspace exists
  validate_seed_workspace "$seed_dir"
  
  # Check if WIP is locked - prevent overwrite if locked
  if wip_is_locked; then
    wip_check_modification_allowed "reinitialization"
    return 1
  fi
  
  log_info "Initializing WIP workspace from seed"
  mkdir -p "$wip_dir"
  
  # Copy seed to wip
  cp -r "$seed_dir"/* "$wip_dir/"
  
  # Add local certificates for development
  mkdir -p "$wip_dir/certs"
  gen_dev_certs
  
  log_success "WIP workspace initialized at $wip_dir"
}

# Build clean prep workspace from WIP workspace
rc_build_prep() {
  # Self-contained: work with project-relative paths
  local project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  local wip_dir="$project_root/workspace/wip"
  local prep_dir="$project_root/workspace/prep"
  
  # Comprehensive validation of WIP workspace
  validate_wip_workspace "$wip_dir"
  
  # Process any new artifacts from intake (future enhancement)
  local intake_dir="$project_root/intake"
  if [[ -d "$intake_dir" ]] && ls "$intake_dir"/*.zip >/dev/null 2>&1; then
    log_info "Processing new artifacts from $intake_dir"
    for zip in "$intake_dir"/*.zip; do
      log_info "Processing: $(basename "$zip")"
      # TODO: Extract and process zip files
    done
  fi
  
  # Build clean prep from wip
  log_info "Building clean prep workspace from WIP"
  rm -rf "$prep_dir"
  mkdir -p "$prep_dir"
  
  # Copy wip content to prep (clean build)
  cp -r "$wip_dir"/* "$prep_dir/" 2>/dev/null || true
  
  # Ensure local certificates are available
  local project_certs="$project_root/certs"
  if [[ -d "$project_certs" ]]; then
    cp "$project_certs"/* "$prep_dir/certs/" 2>/dev/null || true
  fi
  
  log_success "Clean prep workspace built at $prep_dir"
}

# Build zero-entropy deployment package from prep workspace
rc_build_ship() {
  # Self-contained: work with project-relative paths
  local project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  local prep_dir="$project_root/workspace/prep"
  local ship_dir="$project_root/workspace/ship"
  
  # Comprehensive validation of prep workspace
  validate_prep_runtime "$prep_dir"
  
  log_info "🚢 Building self-contained ship deployment package"
  
  # Create clean ship directory
  rm -rf "$ship_dir"
  mkdir -p "$ship_dir"
  
  # Copy prep workspace (the clean build)
  cp -r "$prep_dir"/* "$ship_dir/"
  
  # Copy core scripts for ship package
  cp -r "$project_root/scripts" "$ship_dir/"
  
  # Generate all deployment scripts for different environments
  generate_all_deployment_scripts "$ship_dir"
  
  # Comprehensive validation of the ship package
  validate_ship_package "$ship_dir"
  
  log_info "   Self-contained deployment scripts generated"
  log_info "   Ready for: ship, stage, preprod, prod environments"
  log_info "🚢 Copy $ship_dir/* to deployment target and run ./start-<env>.sh"
}

############################################################################
# Initialize stage environment (future enhancement)
############################################################################
rc_init_stage() {
  log_info "Initializing stage environment"
  log_warn "Stage initialization not yet implemented"
}