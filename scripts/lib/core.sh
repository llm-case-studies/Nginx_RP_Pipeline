#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Colour output helpers
_colour() {
  local code=$1
  shift
  printf '\033[%sm%s\033[0m' "$code" "$*"
}

colour_red() { _colour 31 "$@"; }
colour_green() { _colour 32 "$@"; }
colour_yellow() { _colour 33 "$@"; }

# Logging
log() {
  local emoji=$1
  shift
  printf '%b %s\n' "$emoji" "$*"
}

# Error handler
_die() {
  log "❌" "$*" >&2
  exit 1
}

die() {
  _die "$@"
}

# Ensure required commands exist
require_cmd() {
  local missing=0
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      log "⚠️" "Missing required command: $cmd"
      missing=1
    fi
  done
  [[ $missing -eq 0 ]] || _die "Required command not found"
}

# JSON helper using jq
json_get() {
  require_cmd jq
  local json=$1
  local filter=$2
  echo "$json" | jq -r "$filter"
}
