#!/usr/bin/env bats

# Integration tests for the full pipeline flow: seed→wip→prep→ship

setup() {
  # Set up test environment
  export BATS_TEST_TMPDIR="$BATS_TEST_DIRNAME/../../.bats_tmp"
  mkdir -p "$BATS_TEST_TMPDIR"
}

teardown() {
  # Clean up test artifacts
  rm -rf "$BATS_TEST_TMPDIR" 2>/dev/null || true
}

@test "seed workspace has valid structure" {
  cd "$BATS_TEST_DIRNAME/../.."
  
  # Seed should exist and have required components
  [ -d "workspace/seed" ]
  [ -f "workspace/seed/nginx.conf" ] 
  [ -d "workspace/seed/conf.d" ]
  [ -d "workspace/seed/certs" ]
  [ -d "workspace/seed/info_pages" ]
  
  # Should have modular nginx.conf
  run grep -q "include /etc/nginx/conf.d/\*.conf" workspace/seed/nginx.conf
  [ "$status" -eq 0 ]
}

@test "init-wip creates proper WIP workspace from seed" {
  cd "$BATS_TEST_DIRNAME/../.."
  
  # Clean WIP first
  rm -rf workspace/wip 2>/dev/null || true
  
  # Initialize WIP
  run bash -c "source scripts/lib/core.sh && source scripts/lib/release_ops.sh && rc_init_wip"
  [ "$status" -eq 0 ]
  
  # Verify WIP structure
  [ -d "workspace/wip" ]
  [ -f "workspace/wip/nginx.conf" ]
  [ -d "workspace/wip/conf.d" ]
  [ -d "workspace/wip/certs" ]
  [ -d "workspace/wip/info_pages" ]
  
  # Should have certificates copied from seed
  run find workspace/wip/certs -name "*.cer" -o -name "*.key"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  
  # Should have modular nginx.conf
  run grep -q "include /etc/nginx/conf.d/\*.conf" workspace/wip/nginx.conf
  [ "$status" -eq 0 ]
}

@test "build-prep creates proper prep runtime from WIP" {
  cd "$BATS_TEST_DIRNAME/../.."
  
  # Ensure WIP exists
  if [[ ! -d "workspace/wip" ]]; then
    run bash -c "source scripts/lib/core.sh && source scripts/lib/release_ops.sh && rc_init_wip"
    [ "$status" -eq 0 ]
  fi
  
  # Build prep
  run bash -c "source scripts/lib/core.sh && source scripts/lib/release_ops.sh && rc_build_prep"
  [ "$status" -eq 0 ]
  
  # Verify prep structure
  [ -d "workspace/prep" ]
  [ -f "workspace/prep/nginx.conf" ]
  [ -d "workspace/prep/conf.d" ]
  [ -d "workspace/prep/certs" ]
  [ -d "workspace/prep/info_pages" ]
  
  # Should have certificates from WIP
  run find workspace/prep/certs -name "*.cer" -o -name "*.key"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  
  # Should have modular nginx.conf  
  run grep -q "include /etc/nginx/conf.d/\*.conf" workspace/prep/nginx.conf
  [ "$status" -eq 0 ]
}

@test "build-ship creates self-contained deployment from prep" {
  cd "$BATS_TEST_DIRNAME/../.."
  
  # Ensure prep exists  
  if [[ ! -d "workspace/prep" ]]; then
    # Build the full pipeline
    run bash -c "source scripts/lib/core.sh && source scripts/lib/release_ops.sh && rc_init_wip && rc_build_prep"
    [ "$status" -eq 0 ]
  fi
  
  # Build ship
  run bash -c "source scripts/lib/core.sh && source scripts/lib/release_ops.sh && rc_build_ship"
  [ "$status" -eq 0 ]
  
  # Verify ship structure
  [ -d "workspace/ship" ]
  [ -f "workspace/ship/nginx.conf" ]
  [ -d "workspace/ship/conf.d" ]
  [ -d "workspace/ship/certs" ]
  [ -d "workspace/ship/info_pages" ]
  [ -d "workspace/ship/scripts" ]
  
  # Should have self-contained deployment scripts
  [ -f "workspace/ship/start-ship.sh" ]
  [ -f "workspace/ship/start-stage.sh" ] 
  [ -f "workspace/ship/start-preprod.sh" ]
  [ -f "workspace/ship/start-prod.sh" ]
  
  # Should have certificates from prep
  run find workspace/ship/certs -name "*.cer" -o -name "*.key"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  
  # Should have modular nginx.conf
  run grep -q "include /etc/nginx/conf.d/\*.conf" workspace/ship/nginx.conf
  [ "$status" -eq 0 ]
}

@test "pipeline validation catches missing certificates" {
  cd "$BATS_TEST_DIRNAME/../.."
  
  # Create a broken test scenario
  test_dir="$BATS_TEST_TMPDIR/broken_ship"
  mkdir -p "$test_dir/certs" "$test_dir/conf.d"
  touch "$test_dir/nginx.conf"
  
  # Should fail validation (no certificates)
  run bash -c "source scripts/lib/core.sh && source scripts/lib/validation.sh && validate_ship_package '$test_dir'"
  [ "$status" -eq 1 ]
}

@test "pipeline validation catches broken nginx syntax" {
  cd "$BATS_TEST_DIRNAME/../.."
  
  # Create broken nginx.conf
  test_dir="$BATS_TEST_TMPDIR/broken_syntax"
  mkdir -p "$test_dir/certs" "$test_dir/conf.d"
  echo "broken syntax {" > "$test_dir/nginx.conf"
  
  # Docker syntax check should fail
  run docker run --rm \
    -v "$test_dir/nginx.conf:/etc/nginx/nginx.conf:ro" \
    nginx:latest nginx -t 2>/dev/null
  [ "$status" -ne 0 ]
}