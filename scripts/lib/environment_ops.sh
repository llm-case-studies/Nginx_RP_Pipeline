#!/usr/bin/env bash
# environment_ops.sh - Environment-specific operations (start, stop, manage)
# Extracted from release_ops.sh for better organization

set -euo pipefail

# Variables will be checked when functions are called (defined in core.sh)
# Load config_loader for environment configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config_loader.sh"

############################################################################
# Environment Operations - Start, stop and manage different pipeline stages
############################################################################

# Start seed environment (production replica)
start_seed_environment() {
  local project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  local seed_dir="$project_root/workspace/seed"
  
  if [[ ! -d "$seed_dir" ]]; then
    log_error "No seed found at $seed_dir. Run 'fetch-seed' first."
    return 1
  fi
  
  # Load seed environment configuration
  load_environment_config seed
  
  log_info "Starting seed environment (production replica)"
  
  # Stop existing container
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  
  # Start container with both local and production certs, network access
  docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    -p "$HTTP_PORT:80" -p "$HTTPS_PORT:443" \
    -v "$project_root/certs:/etc/nginx/local-certs:ro" \
    -v "$seed_dir/certs:/etc/nginx/certs:ro" \
    -v "$seed_dir/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -v "$seed_dir/conf.d:/etc/nginx/conf.d:ro" \
    -v "$seed_dir/info_pages:/var/www/info_pages:ro" \
    -v "$seed_dir/nginx-logs:/var/www/NgNix-RP/nginx-logs" \
    nginx:latest
    
  log_success "Seed environment started on ports $HTTP_PORT/$HTTPS_PORT"
}

# Start WIP environment (development workspace)
start_wip_environment() {
  local project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  local wip_dir="$project_root/workspace/wip"
  
  if [[ ! -d "$wip_dir" ]]; then
    log_error "No WIP workspace found at $wip_dir. Run 'init-wip' first."
    return 1
  fi
  
  # Load wip environment configuration
  load_environment_config wip
  
  log_info "Starting WIP environment (development workspace)"
  
  # Stop existing container
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  
  # Start container with runtime build, certificates and network access
  docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    -p "$HTTP_PORT:80" -p "$HTTPS_PORT:443" \
    -v "$wip_dir/certs:/etc/nginx/certs:ro" \
    -v "$project_root/certs:/etc/nginx/local-certs:ro" \
    -v "$wip_dir/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -v "$wip_dir/conf.d:/etc/nginx/conf.d:ro" \
    -v "$wip_dir/info_pages:/var/www/info_pages:ro" \
    -v "$wip_dir/nginx-logs:/var/www/NgNix-RP/nginx-logs" \
    nginx:latest
    
  log_success "WIP environment started on ports $HTTP_PORT/$HTTPS_PORT"
}

# Start prep environment (clean runtime)
start_prep_environment() {
  local project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  local prep_dir="$project_root/workspace/prep"
  
  if [[ ! -d "$prep_dir" ]]; then
    log_error "No prep runtime found at $prep_dir. Run 'build-prep' first."
    return 1
  fi
  
  # Load prep environment configuration
  load_environment_config prep
  
  log_info "Starting prep environment (clean runtime)"
  
  # Stop existing container
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  
  # Start container with runtime build, certificates and network access
  docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    -p "$HTTP_PORT:80" -p "$HTTPS_PORT:443" \
    -v "$prep_dir/certs:/etc/nginx/certs:ro" \
    -v "$project_root/certs:/etc/nginx/local-certs:ro" \
    -v "$prep_dir/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -v "$prep_dir/conf.d:/etc/nginx/conf.d:ro" \
    -v "$prep_dir/info_pages:/var/www/info_pages:ro" \
    -v "$prep_dir/nginx-logs:/var/www/NgNix-RP/nginx-logs" \
    nginx:latest
    
  log_success "Prep environment started on ports $HTTP_PORT/$HTTPS_PORT"
}

# Start ship environment (final verification)
start_ship_environment() {
  local project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  local ship_dir="$project_root/workspace/ship"
  
  if [[ ! -d "$ship_dir" ]]; then
    log_error "No ship package found at $ship_dir. Run 'build-ship' first."
    return 1
  fi
  
  # Build ship from prep first
  log_info "Building ship deployment package from prep runtime"
  
  # Use the prep runtime as source
  local prep_dir="$project_root/workspace/prep"
  if [[ ! -d "$prep_dir" ]]; then
    log_error "No prep runtime found at $prep_dir. Run 'build-prep' first."
    return 1
  fi
  
  # Load ship environment configuration
  load_environment_config ship
  
  # Start ship container
  log_info "Starting ship environment (final verification)"
  
  # Stop existing container
  docker stop "$CONTAINER_NAME" 2>/dev/null || true
  docker rm "$CONTAINER_NAME" 2>/dev/null || true
  
  # Start container with ship package
  docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    -p "$HTTP_PORT:80" -p "$HTTPS_PORT:443" \
    -v "$ship_dir/certs:/etc/nginx/certs:ro" \
    -v "$project_root/certs:/etc/nginx/local-certs:ro" \
    -v "$ship_dir/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -v "$ship_dir/conf.d:/etc/nginx/conf.d:ro" \
    -v "$ship_dir/info_pages:/var/www/info_pages:ro" \
    -v "$ship_dir/nginx-logs:/var/www/NgNix-RP/nginx-logs" \
    nginx:latest
    
  log_success "Ship environment started on ports $HTTP_PORT/$HTTPS_PORT"
}

# Generic environment starter for Type-5 environments
start_typed_environment() {
  local environment="$1"
  local runtime_source="${2:-}"
  
  case "$environment" in
    ship)
      if [[ -n "$runtime_source" ]]; then
        log_info "Starting ship environment with custom runtime: $runtime_source"
        # Use custom runtime source - this would need additional implementation
        log_warn "Custom runtime source not yet implemented"
      fi
      start_ship_environment
      ;;
    stage|preprod|prod)
      log_info "Starting $environment environment"
      # For remote environments, we would typically copy the ship package
      # and run the appropriate start-*.sh script
      log_info "Remote environment deployment not yet implemented"
      log_info "Copy ship package to target and run: ./start-$environment.sh"
      ;;
    *)
      log_error "Unknown environment: $environment"
      log_info "Available environments: ship, stage, preprod, prod"
      return 1
      ;;
  esac
}

# Stop all local containers
stop_all_environments() {
  log_info "Stopping all local containers"
  
  # Use deterministic container names
  local environments=("seed" "wip" "prep" "ship")
  local stopped=0
  
  for env in "${environments[@]}"; do
    # Load config to get proper container name
    load_environment_config "$env" >/dev/null 2>&1
    local container_name="$CONTAINER_NAME"
    
    if docker ps -q --filter "name=$container_name" | grep -q .; then
      log_info "  Stopping $container_name..."
      docker stop "$container_name" >/dev/null 2>&1 || true
      docker rm "$container_name" >/dev/null 2>&1 || true
      ((stopped++))
    fi
  done
  
  if [[ $stopped -eq 0 ]]; then
    log_info "  No containers were running"
  else
    log_success "  Stopped $stopped containers"
  fi
}

# Ensure external services are running
ensure_external_services() {
  log_info "Ensuring external services are running"
  
  # Load ship configuration for network settings
  load_environment_config ship >/dev/null 2>&1
  
  # Create network if it doesn't exist
  if ! docker network ls | grep -q "$NETWORK_NAME"; then
    log_info "Creating $NETWORK_NAME network"
    docker network create "$NETWORK_NAME" --subnet="$NETWORK_SUBNET"
  fi
  
  # Start vaultwarden service if not running
  if ! docker ps | grep -q "$VAULTWARDEN_NAME"; then
    log_info "Starting $VAULTWARDEN_NAME service"
    
    # Ensure data directory exists
    local project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    mkdir -p "$project_root/data/$VAULTWARDEN_NAME"
    
    # Start the service
    docker run -d \
      --name "$VAULTWARDEN_NAME" \
      --network "$NETWORK_NAME" \
      --ip "$VAULTWARDEN_IP" \
      -p "$VAULTWARDEN_PORT:80" \
      -v "$project_root/data/$VAULTWARDEN_NAME:/data" \
      -e WEBSOCKET_ENABLED=true \
      vaultwarden/server:latest || {
        log_warn "vaultwarden/server:latest not available, using nginx placeholder"
        docker run -d \
          --name "$VAULTWARDEN_NAME" \
          --network "$NETWORK_NAME" \
          --ip "$VAULTWARDEN_IP" \
          -p "$VAULTWARDEN_PORT:80" \
          nginx:latest
      }
    
    log_success "$VAULTWARDEN_NAME service started on port $VAULTWARDEN_PORT"
  else
    log_info "$VAULTWARDEN_NAME service already running"
  fi
}

# Legacy function names for backward compatibility
rc_start_seed() { start_seed_environment "$@"; }
rc_start_wip() { start_wip_environment "$@"; }
rc_start_prep() { start_prep_environment "$@"; }
rc_start_ship() { start_ship_environment "$@"; }
rc_start_environment() { start_typed_environment "$@"; }
rc_stop_all() { stop_all_environments "$@"; }
rc_ensure_external_services() { ensure_external_services "$@"; }