#!/usr/bin/env bash
#-------------------------------------------------------------
# ssh_ops.sh – helpers for running commands on prod host
#-------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=core.sh
source "$SCRIPT_DIR/core.sh"

# ssh_cmd <command>
# Executes a command on the production host defined by PROD_SSH
ssh_cmd() {
  require_cmd ssh
  : "${PROD_SSH:?PROD_SSH not set}"
  ssh "$PROD_SSH" "$@"
}
