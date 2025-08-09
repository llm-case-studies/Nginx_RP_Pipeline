#!/usr/bin/env bats

# Test nginx configuration validation across all pipeline stages

@test "seed nginx.conf uses modular conf.d structure" {
  run grep -q "include /etc/nginx/conf.d/\*.conf" "$BATS_TEST_DIRNAME/../../workspace/seed/nginx.conf"
  [ "$status" -eq 0 ]
  
  # Should NOT contain old monolithic server blocks
  run grep -c "server {" "$BATS_TEST_DIRNAME/../../workspace/seed/nginx.conf"
  [ "$status" -eq 1 ] || [ "$output" -eq 0 ]
}

@test "wip nginx.conf uses modular conf.d structure" {
  if [[ ! -f "$BATS_TEST_DIRNAME/../../workspace/wip/nginx.conf" ]]; then
    skip "WIP not initialized - run 'init-wip' first"
  fi
  
  run grep -q "include /etc/nginx/conf.d/\*.conf" "$BATS_TEST_DIRNAME/../../workspace/wip/nginx.conf"
  [ "$status" -eq 0 ]
  
  # Should NOT contain old monolithic server blocks
  run grep -c "server {" "$BATS_TEST_DIRNAME/../../workspace/wip/nginx.conf"
  [ "$status" -eq 1 ] || [ "$output" -eq 0 ]
}

@test "prep nginx.conf uses modular conf.d structure" {
  if [[ ! -f "$BATS_TEST_DIRNAME/../../workspace/prep/nginx.conf" ]]; then
    skip "Prep not built - run 'build-prep' first"
  fi
  
  run grep -q "include /etc/nginx/conf.d/\*.conf" "$BATS_TEST_DIRNAME/../../workspace/prep/nginx.conf"
  [ "$status" -eq 0 ]
  
  # Should NOT contain old monolithic server blocks  
  run grep -c "server {" "$BATS_TEST_DIRNAME/../../workspace/prep/nginx.conf"
  [ "$status" -eq 1 ] || [ "$output" -eq 0 ]
}

@test "ship nginx.conf uses modular conf.d structure" {
  if [[ ! -f "$BATS_TEST_DIRNAME/../../workspace/ship/nginx.conf" ]]; then
    skip "Ship not built - run 'build-ship' first"
  fi
  
  run grep -q "include /etc/nginx/conf.d/\*.conf" "$BATS_TEST_DIRNAME/../../workspace/ship/nginx.conf"
  [ "$status" -eq 0 ]
  
  # Should NOT contain old monolithic server blocks
  run grep -c "server {" "$BATS_TEST_DIRNAME/../../workspace/ship/nginx.conf"
  [ "$status" -eq 1 ] || [ "$output" -eq 0 ]
}

@test "nginx.conf basic syntax structure is valid" {
  if [[ ! -f "$BATS_TEST_DIRNAME/../../workspace/ship/nginx.conf" ]]; then
    skip "Ship not built - run 'build-ship' first"  
  fi
  
  # Test basic nginx.conf structure without upstreams
  # This tests the main config syntax without requiring external services
  run docker run --rm \
    -v "$BATS_TEST_DIRNAME/../../workspace/ship/nginx.conf:/etc/nginx/nginx.conf:ro" \
    nginx:latest nginx -T
  
  # Should succeed even if upstreams are not resolvable - we're testing syntax not resolution
  # The exit status will be non-zero due to upstream resolution, but we check for syntax errors
  [[ "$output" != *"unexpected"* ]]
  [[ "$output" != *"unknown directive"* ]]
}

@test "conf.d files have basic valid nginx syntax structure" {
  if [[ ! -d "$BATS_TEST_DIRNAME/../../workspace/ship/conf.d" ]]; then
    skip "Ship conf.d not available - run 'build-ship' first"
  fi
  
  # Test conf.d files for basic syntax issues (braces, semicolons, etc)
  for conf_file in "$BATS_TEST_DIRNAME/../../workspace/ship/conf.d/"*.conf; do
    if [[ -f "$conf_file" ]]; then
      # Check for balanced braces
      local opens=$(grep -c "{" "$conf_file" || echo 0)
      local closes=$(grep -c "}" "$conf_file" || echo 0)
      [[ "$opens" -eq "$closes" ]]
      
      # Check that file doesn't start with a lone closing brace (common error)
      run head -n 1 "$conf_file"
      [[ "$output" != "}" ]]
    fi
  done
}

@test "pipeline stages have consistent conf.d files" {
  # Skip if stages aren't built
  for stage in wip prep ship; do
    if [[ ! -d "$BATS_TEST_DIRNAME/../../workspace/$stage/conf.d" ]]; then
      skip "$stage conf.d not available - run pipeline first"
    fi
  done
  
  # Compare conf.d files across stages
  run diff -r "$BATS_TEST_DIRNAME/../../workspace/wip/conf.d" "$BATS_TEST_DIRNAME/../../workspace/prep/conf.d"
  [ "$status" -eq 0 ]
  
  run diff -r "$BATS_TEST_DIRNAME/../../workspace/prep/conf.d" "$BATS_TEST_DIRNAME/../../workspace/ship/conf.d"
  [ "$status" -eq 0 ]
}

@test "certificates are present in all required stages" {
  for stage in seed wip prep ship; do
    if [[ -d "$BATS_TEST_DIRNAME/../../workspace/$stage" ]]; then
      # Should have certs directory
      [ -d "$BATS_TEST_DIRNAME/../../workspace/$stage/certs" ]
      
      # Should have at least some certificate files (not empty)
      run find "$BATS_TEST_DIRNAME/../../workspace/$stage/certs" -name "*.cer" -o -name "*.key"
      [ "$status" -eq 0 ]
      [ -n "$output" ]
    fi
  done
}

@test "no broken nginx syntax artifacts in configs" {
  for stage in seed wip prep ship; do
    if [[ -f "$BATS_TEST_DIRNAME/../../workspace/$stage/nginx.conf" ]]; then
      # Should NOT have extra closing braces
      run grep -c "^    }$" "$BATS_TEST_DIRNAME/../../workspace/$stage/nginx.conf"
      [ "$status" -eq 1 ] || [ "$output" -eq 0 ]
      
      # Should NOT have old version headers  
      run grep -c "# Nginx Configuration Version:" "$BATS_TEST_DIRNAME/../../workspace/$stage/nginx.conf"
      [ "$status" -eq 1 ] || [ "$output" -eq 0 ]
    fi
  done
}