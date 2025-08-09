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
    seed)     NETWORK_SUBNET="172.19.0.0/16" ;;
    wip)      NETWORK_SUBNET="172.18.0.0/16" ;;
    prep)     NETWORK_SUBNET="172.17.0.0/16" ;;
    ship)     NETWORK_SUBNET="172.20.0.0/16" ;;
    stage)    NETWORK_SUBNET="172.21.0.0/16" ;;
    preprod)  NETWORK_SUBNET="172.22.0.0/16" ;;
    prod)     NETWORK_SUBNET="172.23.0.0/16" ;;
    *)        NETWORK_SUBNET="172.30.0.0/16" ;;  # Default for unknown envs
  esac

  # Deterministic IP assignments (base + environment offset)
  case "$ENVIRONMENT" in
    seed)     NGINX_IP="172.19.0.10"; VAULTWARDEN_IP="172.19.0.5" ;;
    wip)      NGINX_IP="172.18.0.10"; VAULTWARDEN_IP="172.18.0.5" ;;
    prep)     NGINX_IP="172.17.0.10"; VAULTWARDEN_IP="172.17.0.5" ;;
    ship)     NGINX_IP="172.20.0.10"; VAULTWARDEN_IP="172.20.0.5" ;;
    stage)    NGINX_IP="172.21.0.10"; VAULTWARDEN_IP="172.21.0.5" ;;
    preprod)  NGINX_IP="172.22.0.10"; VAULTWARDEN_IP="172.22.0.5" ;;
    prod)     NGINX_IP="172.23.0.10"; VAULTWARDEN_IP="172.23.0.5" ;;
    *)        NGINX_IP="172.30.0.10"; VAULTWARDEN_IP="172.30.0.5" ;;
  esac

  # Port configuration (environment-specific)
  case "$ENVIRONMENT" in
    seed)     HTTP_PORT=8080; HTTPS_PORT=8443; VAULTWARDEN_PORT=8084 ;;
    wip)      HTTP_PORT=8081; HTTPS_PORT=8444; VAULTWARDEN_PORT=8085 ;;
    prep)     HTTP_PORT=8082; HTTPS_PORT=8445; VAULTWARDEN_PORT=8086 ;;
    ship)     HTTP_PORT=8083; HTTPS_PORT=8446; VAULTWARDEN_PORT=8087 ;;
    stage)    HTTP_PORT=8088; HTTPS_PORT=8447; VAULTWARDEN_PORT=8088 ;;
    preprod)  HTTP_PORT=8089; HTTPS_PORT=8448; VAULTWARDEN_PORT=8089 ;;
    prod)     HTTP_PORT=80;   HTTPS_PORT=443;  VAULTWARDEN_PORT=8090 ;;
    *)        HTTP_PORT=8091; HTTPS_PORT=8449; VAULTWARDEN_PORT=8091 ;;  # Default ports
  esac
}