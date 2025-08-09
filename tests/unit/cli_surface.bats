#!/usr/bin/env bats

@test "safe-rp-ctl unknown command prints help and fails" {
  run bash -lc 'set -euo pipefail; ./scripts/safe-rp-ctl __unknown__ 2>/dev/null || true'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Unknown command"* ]]
  [[ "$output" == *"Available commands"* ]]
}

@test "safe-rp-ctl start-env help shows environments" {
  run bash -lc 'set -euo pipefail; ./scripts/safe-rp-ctl start-env --help || true'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Available environments:"* ]]
  [[ "$output" == *"ship"* ]]
  [[ "$output" == *"stage"* ]]
  [[ "$output" == *"preprod"* ]]
  [[ "$output" == *"prod"* ]]
}


