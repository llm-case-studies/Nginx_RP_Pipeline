#!/usr/bin/env bats

@test "calculate_deterministic_values for stage/preprod/prod" {
  run bash -lc '
    set -eo pipefail
    cd "$BATS_TEST_DIRNAME/../.."
    source environments/base/calculate_deterministic_values.sh
    # Ensure variables referenced downstream are defined when set -u
    DEPLOYMENT_ROOT="/opt/nginx-rp"
    ENVIRONMENT=stage;  calculate_deterministic_values;  echo "$NETWORK_NAME|$HTTP_PORT|$HTTPS_PORT"
    ENVIRONMENT=preprod; calculate_deterministic_values; echo "$NETWORK_NAME|$HTTP_PORT|$HTTPS_PORT"
    ENVIRONMENT=prod;   calculate_deterministic_values; echo "$NETWORK_NAME|$HTTP_PORT|$HTTPS_PORT"
  '
  [ "$status" -eq 0 ]
  IFS=$'\n' read -r l1 l2 l3 <<< "$output"
  [ "$l1" = "nginx-rp-network-stage|8080|8443" ]
  [ "$l2" = "nginx-rp-network-preprod|8081|8444" ]
  [ "$l3" = "nginx-rp-network-prod|80|443" ]
}


