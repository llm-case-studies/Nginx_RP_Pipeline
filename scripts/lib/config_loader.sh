#!/usr/bin/env bash
#-------------------------------------------------------------
# config_loader.sh - Load environment configuration based on entropy model
#-------------------------------------------------------------

# Determine workspace root for relative paths
if [[ -z "${WORKSPACE_ROOT:-}" ]]; then
  WORKSPACE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

CONFIG_ROOT="$WORKSPACE_ROOT/environments"

#-------------------------------------------------------------
# load_environment_config <environment>
# Loads Type-5 configuration for specified environment
#-------------------------------------------------------------
load_environment_config() {
  local env="${1:-ship}"
  
  local base_config="$CONFIG_ROOT/base/type-5-deploy.conf"
  local instance_config="$CONFIG_ROOT/instances/$env/config.conf"
  
  # Load base Type-5 configuration
  if [[ -f "$base_config" ]]; then
    source "$base_config"
  else
    die "Base configuration not found: $base_config"
  fi
  
  # Load environment-specific overrides
  if [[ -f "$instance_config" ]]; then
    source "$instance_config"
  else
    log_warn "Instance configuration not found: $instance_config"
    log_warn "Using base configuration with ENVIRONMENT=$env"
    ENVIRONMENT="$env"
  fi
  
  # Validate required variables are set
  [[ -n "${DEPLOYMENT_ROOT:-}" ]] || die "DEPLOYMENT_ROOT not configured"
  [[ -n "${ENVIRONMENT:-}" ]] || die "ENVIRONMENT not configured"
  
  # Calculate all deterministic values based on final ENVIRONMENT setting
  calculate_deterministic_values
  
  log_info "Loaded $env environment config:"
  log_info "  DEPLOYMENT_ROOT: $DEPLOYMENT_ROOT"
  log_info "  ENVIRONMENT: $ENVIRONMENT"
  log_info "  NETWORK_NAME: $NETWORK_NAME"
  log_info "  CONTAINER_NAME: $CONTAINER_NAME"
}

#-------------------------------------------------------------
# get_legacy_container_name <environment>
# Returns legacy container names for backward compatibility
#-------------------------------------------------------------
get_legacy_container_name() {
  local env="$1"
  case "$env" in
    local)    echo "nginx-rp-local" ;;
    stage)    echo "nginx-rp-stage" ;;
    preprod)  echo "nginx-rp-pre-prod" ;;  # Note: legacy uses hyphen
    prod)     echo "nginx-rp-prod" ;;
    ship)     echo "nginx-rp-ship" ;;
    *)        echo "nginx-rp-${env}" ;;
  esac
}

#-------------------------------------------------------------
# get_legacy_network_name <environment>
# Returns legacy network names for backward compatibility
#-------------------------------------------------------------
get_legacy_network_name() {
  local env="$1"
  case "$env" in
    ship)     echo "pronunco-production" ;;  # Ship connects to existing services
    stage)    echo "nginx-rp-network-stage" ;;
    preprod)  echo "nginx-rp-network-preprod" ;;
    prod)     echo "pronunco-production" ;;  # Production uses legacy name
    *)        echo "nginx-rp-network-${env}" ;;
  esac
}