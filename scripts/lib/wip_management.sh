#!/usr/bin/env bash
# wip_management.sh - WIP workspace locking and management functions
# Extracted from release_ops.sh for better organization

set -euo pipefail

# Variables will be checked when functions are called (defined in core.sh)

############################################################################
# WIP Locking Mechanism - Protect manual integration fixes
############################################################################

# Lock WIP workspace to prevent overwriting manual changes
wip_lock() {
  local reason="${1:-Manual integration fixes applied}"
  local project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  local wip_dir="$project_root/workspace/wip"
  local lock_file="$wip_dir/.lock"
  
  if [[ ! -d "$wip_dir" ]]; then
    log_error "❌ WIP workspace not found at $wip_dir"
    log_error "   Nothing to lock - create WIP workspace first"
    return 1
  fi
  
  if [[ -f "$lock_file" ]]; then
    log_warn "⚠️ WIP workspace is already locked"
    local existing_reason
    existing_reason=$(jq -r '.reason // "No reason specified"' "$lock_file" 2>/dev/null || echo "Lock file corrupted")
    log_info "   Existing reason: $existing_reason"
    log_info "   Use 'unlock-wip' first if you want to change the lock"
    return 0
  fi
  
  # Detect modified files since last build
  local modified_files=()
  if [[ -d "$project_root/workspace/seed" ]]; then
    log_info "🔍 Detecting changes since seed..."
    while IFS= read -r -d '' file; do
      local rel_path="${file#"$wip_dir/"}"
      modified_files+=("$rel_path")
    done < <(find "$wip_dir" -type f -newer "$project_root/workspace/seed" -print0 2>/dev/null || true)
  fi
  
  # Create lock file with metadata
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local user
  user=$(whoami)
  
  cat > "$lock_file" << EOF
{
  "locked_at": "$timestamp",
  "locked_by": "$user",
  "reason": "$reason",
  "modified_files": $(printf '%s\n' "${modified_files[@]}" | jq -R . | jq -s .),
  "wip_state_hash": "$(find "$wip_dir" -type f -exec md5sum {} \; 2>/dev/null | md5sum | cut -d' ' -f1)"
}
EOF
  
  log_success "🔒 WIP workspace locked successfully"
  log_info "   Reason: $reason" 
  log_info "   Protected files: ${#modified_files[@]} detected changes"
  log_info "   Use 'unlock-wip' when ready to allow modifications"
}

# Unlock WIP workspace to allow modifications
wip_unlock() {
  local project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  local wip_dir="$project_root/workspace/wip"
  local lock_file="$wip_dir/.lock"
  
  if [[ ! -f "$lock_file" ]]; then
    log_info "ℹ️ WIP workspace is not locked"
    return 0
  fi
  
  # Show lock info before unlocking
  local lock_info
  lock_info=$(cat "$lock_file" 2>/dev/null || echo '{}')
  local locked_at
  locked_at=$(echo "$lock_info" | jq -r '.locked_at // "Unknown"' 2>/dev/null || echo "Unknown")
  local reason
  reason=$(echo "$lock_info" | jq -r '.reason // "No reason specified"' 2>/dev/null || echo "Lock file corrupted")
  
  log_info "🔓 Unlocking WIP workspace"
  log_info "   Previously locked at: $locked_at"
  log_info "   Reason: $reason"
  
  rm -f "$lock_file"
  log_success "✅ WIP workspace unlocked - modifications now allowed"
}

# Check if WIP workspace is locked (for use in other functions)
wip_is_locked() {
  local wip_dir="$WORKSPACE_ROOT/workspace/wip"
  local lock_file="$wip_dir/.lock"
  
  if [[ -f "$lock_file" ]]; then
    return 0  # Locked
  else
    return 1  # Not locked
  fi
}

# Show WIP lock status and details
wip_status() {
  local wip_dir="$WORKSPACE_ROOT/workspace/wip"
  local lock_file="$wip_dir/.lock"
  
  if [[ ! -d "$wip_dir" ]]; then
    log_info "📁 WIP workspace: Not found"
    return 0
  fi
  
  if [[ ! -f "$lock_file" ]]; then
    log_info "📁 WIP workspace: Unlocked (modifications allowed)"
    return 0
  fi
  
  log_info "📁 WIP workspace: Locked 🔒"
  local lock_info
  lock_info=$(cat "$lock_file" 2>/dev/null || echo '{}')
  
  local locked_at
  locked_at=$(echo "$lock_info" | jq -r '.locked_at // "Unknown"' 2>/dev/null || echo "Unknown")
  local locked_by  
  locked_by=$(echo "$lock_info" | jq -r '.locked_by // "Unknown"' 2>/dev/null || echo "Unknown")
  local reason
  reason=$(echo "$lock_info" | jq -r '.reason // "No reason specified"' 2>/dev/null || echo "Lock file corrupted")
  
  log_info "   Locked at: $locked_at"
  log_info "   Locked by: $locked_by"
  log_info "   Reason: $reason"
  
  # Show modified files if available
  local modified_files
  modified_files=$(echo "$lock_info" | jq -r '.modified_files[]?' 2>/dev/null)
  if [[ -n "$modified_files" ]]; then
    log_info "   Protected changes:"
    echo "$modified_files" | head -5 | sed 's/^/     - /'
    local total_files
    total_files=$(echo "$modified_files" | wc -l)
    if [[ $total_files -gt 5 ]]; then
      log_info "     ... and $((total_files - 5)) more files"
    fi
  fi
}

# Check if WIP workspace can be safely modified
wip_check_modification_allowed() {
  local operation="${1:-modification}"
  local wip_dir="$WORKSPACE_ROOT/workspace/wip"
  local lock_file="$wip_dir/.lock"
  
  if [[ ! -f "$lock_file" ]]; then
    return 0  # Not locked, modification allowed
  fi
  
  # WIP is locked - show error and guidance
  log_error "❌ WIP workspace is locked and cannot be modified"
  local lock_info
  lock_info=$(cat "$lock_file" 2>/dev/null || echo '{}')
  local reason
  reason=$(echo "$lock_info" | jq -r '.reason // "No reason specified"' 2>/dev/null || echo "Lock file corrupted")
  log_error "   Reason: $reason"
  log_error "   Use 'unlock-wip' first if you want to allow $operation"
  log_error "   WARNING: This will lose all manual changes in WIP workspace!"
  
  return 1  # Locked, modification not allowed
}

# Get lock information as JSON (for programmatic use)
wip_get_lock_info() {
  local wip_dir="$WORKSPACE_ROOT/workspace/wip"
  local lock_file="$wip_dir/.lock"
  
  if [[ ! -f "$lock_file" ]]; then
    echo '{"locked": false}'
    return 0
  fi
  
  local lock_info
  lock_info=$(cat "$lock_file" 2>/dev/null || echo '{}')
  echo "$lock_info" | jq '. + {"locked": true}' 2>/dev/null || echo '{"locked": true, "error": "corrupted_lock_file"}'
}

# Legacy function names for backward compatibility
rc_lock_wip() { wip_lock "$@"; }
rc_unlock_wip() { wip_unlock "$@"; }
rc_check_wip_lock() { wip_is_locked "$@"; }
rc_wip_status() { wip_status "$@"; }