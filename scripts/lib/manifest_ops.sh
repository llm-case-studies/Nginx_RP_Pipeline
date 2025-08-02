#!/usr/bin/env bash
#-------------------------------------------------------------
# manifest_ops.sh – helpers for release manifest handling
#-------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core.sh
source "$SCRIPT_DIR/core.sh"

# manifest_write <release_id> <note> <apps_json>
# Writes runtime/release.json with metadata and app list
manifest_write() {
  local id="$1"; shift
  local note="$1"; shift
  local apps_json="$1"
  require_cmd jq
  local built_at
  built_at="$(date -u +%FT%TZ)"
  local built_by
  built_by="$(whoami)@$(hostname)"
  jq -n --arg id "$id" \
        --arg built_at "$built_at" \
        --arg built_by "$built_by" \
        --arg note "$note" \
        --argjson apps "$apps_json" \
        '{id:$id,built_at_utc:$built_at,built_by:$built_by,note:$note,apps:$apps}' \
        > "$RUNTIME_DIR/release.json"
}

# manifest_pretty <path>
manifest_pretty() {
  local file="$1"
  require_cmd jq
  jq . "$file"
}

