#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# shellcheck source=core.sh
source "$(dirname "${BASH_SOURCE[0]}")/core.sh"
# shellcheck source=docker_ops.sh
source "$(dirname "${BASH_SOURCE[0]}")/docker_ops.sh"

rc_build_local() {
  require_cmd unzip
  local intake_dir="${INTAKE_DIR:-/mnt/pipeline-intake}"
  local artefact
  artefact=$(ls "$intake_dir"/*.zip 2>/dev/null | head -n1 || true)
  [[ -f "$artefact" ]] || die "No artefact found in $intake_dir"

  rm -rf "$ROOT_DIR/runtime"
  mkdir -p "$ROOT_DIR/runtime"
  unzip -q "$artefact" -d "$ROOT_DIR/runtime"

  ensure_network
  dk_stop
  dk_run

  log "✅" "Local build complete"
}
