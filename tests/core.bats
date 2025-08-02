#!/usr/bin/env bats

@test "log_info prints icon and message" {
  run bash -c 'source scripts/lib/core.sh; log_info "hello"'
  [ "$status" -eq 0 ]
  [ "$output" = "ℹ️  hello" ]
}

@test "die exits with message" {
  run bash -c 'source scripts/lib/core.sh; die "fail"'
  [ "$status" -eq 1 ]
  [ "$output" = "✖ fail" ]
}

@test "require_cmd fails on missing command" {
  run bash -c 'source scripts/lib/core.sh; require_cmd some_missing_cmd'
  [ "$status" -ne 0 ]
}

@test "json_get extracts value" {
  run bash -c 'source scripts/lib/core.sh; json_get "{\"a\":1}" .a'
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}
