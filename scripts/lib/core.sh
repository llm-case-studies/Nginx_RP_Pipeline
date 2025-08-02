#!/usr/bin/env bash
#-------------------------------------------------------------
# core.sh  –  generic helpers used by every safe‑rp‑ctl module
#-------------------------------------------------------------
# This file is source‑only (never executed directly).  Keep it
# dependency‑free so it can run on the minimal POSIX shell
# available on stage/pre‑prod/prod hosts.
#-------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

# Detect TTY for colours ------------------------------------------------
if [[ -t 2 ]]; then
  _col_reset="$(tput sgr0)"  || true
  _col_red="$(tput setaf 1)"  || true
  _col_yel="$(tput setaf 3)"  || true
  _col_grn="$(tput setaf 2)"  || true
else
  _col_reset=""; _col_red=""; _col_yel=""; _col_grn="";
fi

# Logging helpers -------------------------------------------------------
_log() {
  local icon="$1"; shift
  printf '%b%s%b %s\n' "${_col_grn}" "${icon}" "${_col_reset}" "$*" || true
  return 0
}

log_info()    { _log "ℹ️ " "$*"; }
log_success() { _log "✅" "$*"; }
log_warn() {
  printf '%b⚠️  %s%b\n'  "${_col_yel}" "$*" "${_col_reset}" || true
  return 0
}
log_error() {
  printf '%b✖ %s%b\n' "${_col_red}" "$*" "${_col_reset}" || true
  return 0
}

die() {
  log_error "$*" >&2
  exit 1
}

# Cmd dependency check --------------------------------------------------
require_cmd() {
  local cmd=$1
  command -v "$cmd" >/dev/null 2>&1 || die "Required command '$cmd' not found in PATH"
}

# Small JSON getter using jq -------------------------------------------
#   json_get '{"foo": {"bar": 42}}' .foo.bar    -> 42
json_get() {
  local json=$1; local jq_expr=$2
  echo "$json" | jq -r "$jq_expr"
}

# Timestamp helper (UTC, sortable) -------------------------------------
now_ts() { date -u '+%Y%m%d-%H%M%S'; }

gen_dev_certs() {
  require_cmd mkcert openssl
  local cert_dir="$WORKSPACE_ROOT/certs"
  mkdir -p "$cert_dir"
  local marker="$cert_dir/.mkcert_installed"
  if [[ ! -f "$marker" ]]; then
    mkcert -install
    touch "$marker"
  fi
  if [[ ! -f "$cert_dir/cert.pem" || ! -f "$cert_dir/key.pem" ]]; then
    mkcert -cert-file "$cert_dir/cert.pem" -key-file "$cert_dir/key.pem" localhost 127.0.0.1 ::1
  fi
}
