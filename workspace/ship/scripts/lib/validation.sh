#!/usr/bin/env bash
# validation.sh - Comprehensive validation functions for pipeline stages
# Extracted from release_ops.sh for better maintainability

set -euo pipefail

############################################################################
# Validation Functions - Ensure pipeline stage completeness and correctness
############################################################################

# Validate WIP workspace completeness before building prep
validate_wip_workspace() {
  local wip_dir="$1"
  local validation_failed=false
  
  log_info "🔍 Validating WIP workspace completeness..."
  
  if [[ ! -d "$wip_dir" ]]; then
    log_error "❌ WIP workspace not found at $wip_dir"
    log_error "   Run 'init-wip' first to create integration workspace"
    return 1
  fi
  
  # Check if WIP is locked - just report status, don't fail
  if [[ -f "$wip_dir/.lock" ]]; then
    log_info "🔒 WIP workspace is locked (contains manual fixes)"
    local lock_info
    lock_info=$(cat "$wip_dir/.lock" 2>/dev/null || echo '{}')
    local reason
    reason=$(echo "$lock_info" | jq -r '.reason // "No reason specified"' 2>/dev/null || echo "Lock file corrupted")
    log_info "   Reason: $reason"
    log_info "   Proceeding with locked state (preserving manual changes)"
  fi
  
  # Check essential directories
  for dir in conf.d info_pages certs; do
    if [[ ! -d "$wip_dir/$dir" ]]; then
      log_error "❌ Missing critical directory in WIP: $dir"
      validation_failed=true
    else
      log_info "   ✅ WIP directory present: $dir"
    fi
  done
  
  # Check essential files  
  if [[ ! -f "$wip_dir/nginx.conf" ]]; then
    log_error "❌ Missing nginx.conf in WIP workspace"
    validation_failed=true
  else
    log_info "   ✅ WIP nginx.conf present"
  fi
  
  # Verify certificates exist
  if [[ -d "$wip_dir/certs" ]]; then
    local cert_count
    cert_count=$(find "$wip_dir/certs" -name "*.cer" -o -name "*.pem" -o -name "*.key" 2>/dev/null | wc -l)
    if [[ $cert_count -eq 0 ]]; then
      log_error "❌ No certificate files found in WIP certs directory"
      log_error "   WIP should contain production certs (from seed) + new app certs"
      validation_failed=true
    else
      log_info "   ✅ Found $cert_count certificate files in WIP"
    fi
  fi
  
  # Check nginx configuration syntax if nginx available
  if command -v nginx >/dev/null 2>&1; then
    log_info "   🔍 Testing WIP nginx configuration syntax..."
    if nginx -t -c "$wip_dir/nginx.conf" -p "$wip_dir" >/dev/null 2>&1; then
      log_info "   ✅ WIP nginx configuration syntax valid"
    else
      log_error "❌ WIP nginx configuration syntax invalid"
      nginx -t -c "$wip_dir/nginx.conf" -p "$wip_dir" 2>&1 | head -3
      validation_failed=true
    fi
  fi
  
  if [[ "$validation_failed" == "true" ]]; then
    log_error "🚨 WIP VALIDATION FAILED!"
    log_error "   Cannot build prep from incomplete WIP workspace"
    log_error "   Fix WIP issues first, then retry build-prep"
    return 1
  fi
  
  log_success "✅ WIP validation passed - ready to build prep"
  return 0
}

# Validate prep runtime completeness before building ship
validate_prep_runtime() {
  local runtime_dir="$1"
  local validation_failed=false
  
  log_info "🔍 Validating prep runtime completeness..."
  
  if [[ ! -d "$runtime_dir" ]]; then
    log_error "❌ Prep runtime not found at $runtime_dir"
    log_error "   Run 'build-prep' first to create clean runtime"
    return 1
  fi
  
  # Check essential directories
  for dir in conf.d info_pages certs; do
    if [[ ! -d "$runtime_dir/$dir" ]]; then
      log_error "❌ Missing critical directory in prep runtime: $dir"
      validation_failed=true
    else
      log_info "   ✅ Prep directory present: $dir"
    fi
  done
  
  # Check essential files
  if [[ ! -f "$runtime_dir/nginx.conf" ]]; then
    log_error "❌ Missing nginx.conf in prep runtime"
    validation_failed=true
  else
    log_info "   ✅ Prep nginx.conf present"
  fi
  
  # Verify certificates exist
  if [[ -d "$runtime_dir/certs" ]]; then
    local cert_count
    cert_count=$(find "$runtime_dir/certs" -name "*.cer" -o -name "*.pem" -o -name "*.key" 2>/dev/null | wc -l)
    if [[ $cert_count -eq 0 ]]; then
      log_error "❌ No certificate files found in prep runtime certs directory"
      log_error "   Prep runtime should contain clean certificate set from WIP"
      validation_failed=true
    else
      log_info "   ✅ Found $cert_count certificate files in prep runtime"
    fi
  fi
  
  # Check nginx configuration syntax
  if command -v nginx >/dev/null 2>&1; then
    log_info "   🔍 Testing prep nginx configuration syntax..."
    if nginx -t -c "$runtime_dir/nginx.conf" -p "$runtime_dir" >/dev/null 2>&1; then
      log_info "   ✅ Prep nginx configuration syntax valid"
    else
      log_error "❌ Prep nginx configuration syntax invalid"
      nginx -t -c "$runtime_dir/nginx.conf" -p "$runtime_dir" 2>&1 | head -3
      validation_failed=true
    fi
  fi
  
  if [[ "$validation_failed" == "true" ]]; then
    log_error "🚨 PREP RUNTIME VALIDATION FAILED!"
    log_error "   Cannot build ship from incomplete prep runtime" 
    log_error "   Fix prep runtime issues first, then retry build-ship"
    return 1
  fi
  
  log_success "✅ Prep runtime validation passed - ready to build ship"
  return 0
}

# Validate ship package completeness after building
validate_ship_package() {
  local ship_dir="$1"
  local validation_failed=false
  
  log_info "🔍 Verifying ship package completeness..."
  
  # Check essential directories exist
  for dir in certs conf.d info_pages scripts; do
    if [[ ! -d "$ship_dir/$dir" ]]; then
      log_error "❌ Missing critical directory: $dir"
      validation_failed=true
    else
      log_info "   ✅ Directory present: $dir"
    fi
  done
  
  # Check essential files exist
  for file in nginx.conf README.md; do
    if [[ ! -f "$ship_dir/$file" ]]; then
      log_error "❌ Missing critical file: $file"
      validation_failed=true
    else
      log_info "   ✅ File present: $file"
    fi
  done
  
  # Verify certificates are present
  if [[ -d "$ship_dir/certs" ]]; then
    local cert_count
    cert_count=$(find "$ship_dir/certs" -name "*.cer" -o -name "*.pem" -o -name "*.key" | wc -l)
    if [[ $cert_count -eq 0 ]]; then
      log_error "❌ No certificate files found in certs/ directory"
      validation_failed=true
    else
      log_info "   ✅ Found $cert_count certificate files"
    fi
  fi
  
  # Check nginx config syntax
  if command -v nginx >/dev/null 2>&1; then
    log_info "   🔍 Testing nginx configuration syntax..."
    if nginx -t -c "$ship_dir/nginx.conf" -p "$ship_dir" >/dev/null 2>&1; then
      log_info "   ✅ Nginx configuration syntax valid"
    else
      log_error "❌ Nginx configuration syntax invalid"
      nginx -t -c "$ship_dir/nginx.conf" -p "$ship_dir" 2>&1 | head -5
      validation_failed=true
    fi
  else
    log_warn "   ⚠️ nginx not available for syntax checking"
  fi
  
  # Verify deployment scripts were generated
  for env in ship stage preprod prod; do
    if [[ ! -f "$ship_dir/start-${env}.sh" ]]; then
      log_error "❌ Missing deployment script: start-${env}.sh"
      validation_failed=true
    elif [[ ! -x "$ship_dir/start-${env}.sh" ]]; then
      log_error "❌ Deployment script not executable: start-${env}.sh"
      validation_failed=true
    else
      log_info "   ✅ Deployment script ready: start-${env}.sh"
    fi
  done
  
  if [[ "$validation_failed" == "true" ]]; then
    log_error "🚨 SHIP PACKAGE VALIDATION FAILED!"
    log_error "   Package is incomplete and MUST NOT be deployed"
    log_error "   Fix the issues above and rebuild"
    return 1
  fi
  
  log_success "✅ Ship package verification passed - ready for deployment"
  return 0
}

# Validate seed workspace has production data
validate_seed_workspace() {
  local seed_dir="$1"
  
  log_info "🔍 Validating seed workspace..."
  
  if [[ ! -d "$seed_dir" ]]; then
    log_error "❌ Seed workspace not found at $seed_dir"
    log_error "   Run 'fetch-seed' first to get production snapshot"
    return 1
  fi
  
  # Check for basic production structure
  if [[ ! -f "$seed_dir/nginx.conf" ]]; then
    log_error "❌ Missing nginx.conf in seed workspace"
    return 1
  fi
  
  if [[ ! -d "$seed_dir/certs" ]] || [[ -z "$(ls -A "$seed_dir/certs" 2>/dev/null)" ]]; then
    log_warn "⚠️ No certificates found in seed workspace"
    log_warn "   This may be expected for non-production environments"
  else
    log_info "   ✅ Production certificates present"
  fi
  
  log_success "✅ Seed workspace validation passed"
  return 0
}