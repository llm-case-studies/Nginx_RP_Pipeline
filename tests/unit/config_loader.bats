#!/usr/bin/env bats

load() {
  # Helper to run a bash snippet in repo root
  bash -lc "set -euo pipefail; cd '$BATS_TEST_DIRNAME/../..'; $*"
}

@test "load_environment_config ship computes deterministic values" {
  run bash -lc "
    set -eo pipefail
    cd '$BATS_TEST_DIRNAME/../..'
    source scripts/lib/core.sh
    source scripts/lib/config_loader.sh
    load_environment_config ship >/dev/null 2>&1
    echo \"\$NETWORK_NAME|\$CONTAINER_NAME|\$HTTP_PORT|\$HTTPS_PORT\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "nginx-rp-network-ship|nginx-rp-ship|8083|8446" ]
}

@test "load_environment_config prod computes deterministic values" {
  run bash -lc "
    set -eo pipefail
    cd '$BATS_TEST_DIRNAME/../..'
    source scripts/lib/core.sh
    source scripts/lib/config_loader.sh
    load_environment_config prod >/dev/null 2>&1
    echo \"\$NETWORK_NAME|\$CONTAINER_NAME|\$HTTP_PORT|\$HTTPS_PORT\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "nginx-rp-network-prod|nginx-rp-prod|80|443" ]
}


