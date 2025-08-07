#!/usr/bin/env bash
# calculate_deterministic_values.sh - Recalculate deterministic values after ENVIRONMENT is set

# This function should be called after ENVIRONMENT is properly set by instance configs
calculate_deterministic_values() {
  # Deterministic naming based on ENVIRONMENT
  NETWORK_NAME="nginx-rp-network-${ENVIRONMENT}"
  CONTAINER_NAME="nginx-rp-${ENVIRONMENT}"
  BACKUP_ROOT="${DEPLOYMENT_ROOT}/backups"

  # Deterministic service naming
  VAULTWARDEN_NAME="vaultwarden-${ENVIRONMENT}"
  POSTGRES_NAME="postgres-${ENVIRONMENT}"
  REDIS_NAME="redis-${ENVIRONMENT}"

  # Network configuration (environment-specific subnets) 
  case "$ENVIRONMENT" in
    ship)     NETWORK_SUBNET="172.20.0.0/16" ;;
    stage)    NETWORK_SUBNET="172.21.0.0/16" ;;
    preprod)  NETWORK_SUBNET="172.22.0.0/16" ;;
    prod)     NETWORK_SUBNET="172.23.0.0/16" ;;
    *)        NETWORK_SUBNET="172.30.0.0/16" ;;  # Default for unknown envs
  esac

  # Deterministic IP assignments (base + environment offset)
  case "$ENVIRONMENT" in
    ship)     NGINX_IP="172.20.0.10"; VAULTWARDEN_IP="172.20.0.5" ;;
    stage)    NGINX_IP="172.21.0.10"; VAULTWARDEN_IP="172.21.0.5" ;;
    preprod)  NGINX_IP="172.22.0.10"; VAULTWARDEN_IP="172.22.0.5" ;;
    prod)     NGINX_IP="172.23.0.10"; VAULTWARDEN_IP="172.23.0.5" ;;
    *)        NGINX_IP="172.30.0.10"; VAULTWARDEN_IP="172.30.0.5" ;;
  esac

  # Port configuration (environment-specific)
  case "$ENVIRONMENT" in
    ship)     HTTP_PORT=8083; HTTPS_PORT=8446; VAULTWARDEN_PORT=8223 ;;
    stage)    HTTP_PORT=8080; HTTPS_PORT=8443; VAULTWARDEN_PORT=8224 ;;
    preprod)  HTTP_PORT=8081; HTTPS_PORT=8444; VAULTWARDEN_PORT=8225 ;;
    prod)     HTTP_PORT=80;   HTTPS_PORT=443;  VAULTWARDEN_PORT=8226 ;;
    *)        HTTP_PORT=8082; HTTPS_PORT=8445; VAULTWARDEN_PORT=8227 ;;  # Default ports
  esac
}