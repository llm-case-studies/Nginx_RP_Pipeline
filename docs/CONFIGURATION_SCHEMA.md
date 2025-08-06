# Configuration Schema: Entropy-Based Path Management

## Overview
This document defines the hierarchical configuration system for the nginx reverse proxy pipeline, implementing the entropy reduction model where configuration complexity decreases as we move from high-entropy build stages to zero-entropy deployment packages.

## Configuration Architecture

### Base Configuration Files
```
environments/
├── base/
│   ├── type-1-build.conf      # High entropy: 25-30 parameters
│   ├── type-2-develop.conf    # Medium-high: 15-20 parameters  
│   ├── type-3-verify.conf     # Medium: 10-15 parameters
│   ├── type-4-stage.conf      # Low: 5-8 parameters
│   └── type-5-deploy.conf     # Zero: 2 parameters only!
├── instances/
│   ├── local-dev/            # Type-2 instance
│   ├── ci-build/             # Type-1 instance  
│   ├── staging/              # Type-3 instance
│   ├── ship/                 # Type-5 instance
│   ├── stage/                # Type-5 instance  
│   ├── pre-prod/             # Type-5 instance
│   └── production/           # Type-5 instance
└── common/
    ├── container-mounts.conf  # Fixed Docker mount paths
    └── network-templates.conf # Network configuration patterns
```

## Current Hardcoded Paths Analysis

Based on analysis of the codebase, we identified these categories of hardcoded paths:

### Core Paths (Type-1 to Type-5)
```bash
# Workspace Management (Type-1: Build/Integration)
WORKSPACE_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
INTAKE_DIR="/mnt/pipeline-intake"
BUILD_CACHE_ROOT="$WORKSPACE_ROOT/.build-cache"
EXTERNAL_DEPS_ROOT="/opt/external-deps"

# Development Paths (Type-2: Development/Testing)  
WIP_DIR="$WORKSPACE_ROOT/workspace/wip"
DEV_WORKSPACE_ROOT="$WORKSPACE_ROOT/workspace"
CERT_STORE_ROOT="$WORKSPACE_ROOT/certs"
SERVICE_CONFIG_ROOT="$WORKSPACE_ROOT/services"

# Verification Paths (Type-3: Staging/Verification)
PREP_DIR="$WORKSPACE_ROOT/workspace/prep"
CLEAN_BUILD_ROOT="/tmp/clean-builds"
VERIFICATION_ROOT="/tmp/verification"
STAGING_CONFIG_ROOT="$WORKSPACE_ROOT/staging-configs"

# Pre-deployment Paths (Type-4: Pre-deployment)
SHIP_DIR="$WORKSPACE_ROOT/workspace/ship"
DEPLOYMENT_SIMULATION_ROOT="/tmp/deploy-simulation"
FINAL_ARTIFACT_ROOT="$WORKSPACE_ROOT/artifacts"

# Deployment Paths (Type-5: Deployment Package)
DEPLOYMENT_ROOT="/opt/nginx-rp"
BACKUP_ROOT="/opt/backups"
```

### Container Configuration (All Types)
```bash
# Container Names (Environment-specific)
CNT_LOCAL="nginx-rp-local"
CNT_STAGE="nginx-rp-stage"  
CNT_PREPROD="nginx-rp-pre-prod"
CNT_PROD="nginx-rp-prod"

# Network Configuration
NETWORK_PRODUCTION="pronunco-production"
NETWORK_STAGE="nginx-rp-network-stage"
NETWORK_PREPROD="nginx-rp-network-preprod"

# Docker Images
IMAGE="nginx:latest"
VAULTWARDEN_IMAGE="vaultwarden/server:latest"
```

### Fixed Container Paths (Common across all types)
```bash
# These should NOT be configurable - they're internal to containers
NGINX_CONF_PATH="/etc/nginx/nginx.conf"
NGINX_CONF_D="/etc/nginx/conf.d"
NGINX_CERTS="/etc/nginx/certs"
NGINX_LOCAL_CERTS="/etc/nginx/local-certs"
WWW_ROOT="/var/www"
INFO_PAGES="/var/www/info_pages"
LOG_PATH="/var/www/NgNix-RP/nginx-logs"
```

### Production Environment Paths (Type-4/Type-5)
```bash
# SSH and Remote Paths
PROD_SSH="${PROD_SSH:-proxyuser@prod}"
PROD_ROOT="${PROD_ROOT:-/home/proxyuser/NgNix-RP}"
STAGE_SSH="${STAGE_SSH:-deploy@stage}"
STAGE_ROOT="${STAGE_ROOT:-/home/deploy/pre-prod-stage/proxyuser}"
```

## Configuration Inheritance Model

### Type-1 (Build/Integration) - Inherits ALL
- Can access ALL path types (build, develop, verify, stage, deploy)
- Maximum configurability for artifact ingestion
- Local development and CI/CD build environments

```bash
# type-1-build.conf
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(pwd)}"
INTAKE_DIR="${INTAKE_DIR:-/mnt/pipeline-intake}"
BUILD_CACHE_ROOT="${BUILD_CACHE_ROOT:-$WORKSPACE_ROOT/.build-cache}"
WIP_DIR="${WIP_DIR:-$WORKSPACE_ROOT/workspace/wip}"
PREP_DIR="${PREP_DIR:-$WORKSPACE_ROOT/workspace/prep}"
SHIP_DIR="${SHIP_DIR:-$WORKSPACE_ROOT/workspace/ship}"
DEPLOYMENT_ROOT="${DEPLOYMENT_ROOT:-/opt/nginx-rp}"
# ... 25-30 total configurable paths
```

### Type-2 (Development/Testing) - Inherits Type-2→Type-5
- Cannot do intake/build operations
- Focused on development workflow and testing

```bash
# type-2-develop.conf  
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(pwd)}"
WIP_DIR="${WIP_DIR:-$WORKSPACE_ROOT/workspace/wip}"
PREP_DIR="${PREP_DIR:-$WORKSPACE_ROOT/workspace/prep}"
SHIP_DIR="${SHIP_DIR:-$WORKSPACE_ROOT/workspace/ship}"
DEPLOYMENT_ROOT="${DEPLOYMENT_ROOT:-/opt/nginx-rp}"
# ... 15-20 total configurable paths
```

### Type-3 (Staging/Verification) - Inherits Type-3→Type-5
- Clean build verification only
- Environment-specific configurations

```bash
# type-3-verify.conf
PREP_DIR="${PREP_DIR:-$WORKSPACE_ROOT/workspace/prep}"
SHIP_DIR="${SHIP_DIR:-$WORKSPACE_ROOT/workspace/ship}"
DEPLOYMENT_ROOT="${DEPLOYMENT_ROOT:-/opt/nginx-rp}"
VERIFICATION_ROOT="${VERIFICATION_ROOT:-/tmp/verification}"
# ... 10-15 total configurable paths
```

### Type-4 (Pre-deployment) - Inherits Type-4→Type-5  
- Final verification with deployment-like config
- Minimal variability

```bash
# type-4-stage.conf
SHIP_DIR="${SHIP_DIR:-$WORKSPACE_ROOT/workspace/ship}"
DEPLOYMENT_ROOT="${DEPLOYMENT_ROOT:-/opt/nginx-rp}"
BACKUP_ROOT="${BACKUP_ROOT:-/opt/backups}"
DEPLOYMENT_SIMULATION_ROOT="${DEPLOYMENT_SIMULATION_ROOT:-/tmp/deploy-simulation}"
# ... 5-8 total configurable paths
```

### Type-5 (Deployment Package) - Self-contained
- **Minimal configuration**: 2 parameters only!
- Maximum reproducibility with deterministic naming
- Production deployment ready

```bash
# type-5-deploy.conf - DETERMINISTIC NAMING SYSTEM
DEPLOYMENT_ROOT="${DEPLOYMENT_ROOT:-/opt/nginx-rp}"
ENVIRONMENT="${ENVIRONMENT:-prod}"

# Everything else becomes deterministic:
NETWORK_NAME="nginx-rp-network-${ENVIRONMENT}"
CONTAINER_NAME="nginx-rp-${ENVIRONMENT}"
BACKUP_ROOT="${DEPLOYMENT_ROOT}/backups"
```

## Deterministic Naming Convention

### **Networks:** `nginx-rp-network-<env>`
```bash
nginx-rp-network-ship      # Local final verification (172.20.0.0/16)
nginx-rp-network-stage     # IONOS staging (172.21.0.0/16)  
nginx-rp-network-preprod   # Pre-production (172.22.0.0/16)
nginx-rp-network-prod      # Production (172.23.0.0/16)
```

### **Main Containers:** `nginx-rp-<env>`
```bash
nginx-rp-ship              # Ship container
nginx-rp-stage             # Stage container
nginx-rp-preprod           # Pre-prod container  
nginx-rp-prod              # Production container
```

### **App Containers:** `<app>-<env>`
```bash
vaultwarden-ship           # Ship vaultwarden
vaultwarden-stage          # Stage vaultwarden
vaultwarden-preprod        # Pre-prod vaultwarden
vaultwarden-prod           # Production vaultwarden
```

## Environment Instance Configurations

### Ship (Type-5) - Local Final Verification
```bash
# instances/ship/config.conf
source ../base/type-5-deploy.conf

DEPLOYMENT_ROOT="$WORKSPACE_ROOT/workspace/ship"
ENVIRONMENT="ship"
# Deterministic: nginx-rp-network-ship, nginx-rp-ship, vaultwarden-ship
```

### Stage (Type-5) - IONOS Staging
```bash
# instances/stage/config.conf  
source ../base/type-5-deploy.conf

DEPLOYMENT_ROOT="/home/deploy/pre-prod-stage/proxyuser"
ENVIRONMENT="stage" 
DEPLOYMENT_SSH="deploy@stage"
# Deterministic: nginx-rp-network-stage, nginx-rp-stage, vaultwarden-stage
```

### Pre-prod (Type-5) - Pre-production Verification
```bash
# instances/pre-prod/config.conf
source ../base/type-5-deploy.conf

DEPLOYMENT_ROOT="/home/proxyuser/pre-prod"
ENVIRONMENT="preprod"
DEPLOYMENT_SSH="proxyuser@preprod"
# Deterministic: nginx-rp-network-preprod, nginx-rp-preprod, vaultwarden-preprod
```

### Production (Type-5) - Final Deployment
```bash
# instances/production/config.conf
source ../base/type-5-deploy.conf

DEPLOYMENT_ROOT="/home/proxyuser/NgNix-RP"
ENVIRONMENT="prod"
DEPLOYMENT_SSH="proxyuser@prod"
# Deterministic: nginx-rp-network-prod, nginx-rp-prod, vaultwarden-prod
```

## Usage in Scripts

### Configuration Loading
```bash
#!/usr/bin/env bash
# Enhanced script header with configuration loading

# Determine environment type and load appropriate config
ENV_TYPE="${ENV_TYPE:-type-2}"  # Default to development
ENV_INSTANCE="${ENV_INSTANCE:-local-dev}"

CONFIG_DIR="$(dirname "${BASH_SOURCE[0]}")/../environments"
BASE_CONFIG="$CONFIG_DIR/base/$ENV_TYPE.conf"
INSTANCE_CONFIG="$CONFIG_DIR/instances/$ENV_INSTANCE/config.conf"

# Load base configuration
[[ -f "$BASE_CONFIG" ]] && source "$BASE_CONFIG"
# Load instance-specific overrides  
[[ -f "$INSTANCE_CONFIG" ]] && source "$INSTANCE_CONFIG"
```

### Entropy Validation
```bash
# Validate entropy reduction between stages
validate_entropy_reduction() {
    local from_type="$1"
    local to_type="$2"
    
    local from_paths=$(count_configurable_paths "$from_type")
    local to_paths=$(count_configurable_paths "$to_type")
    
    if [[ $from_paths -le $to_paths ]]; then
        die "❌ Pipeline violation: Entropy should decrease ($from_type:$from_paths → $to_type:$to_paths)"
    fi
    
    log_info "✅ Entropy reduced: $from_type ($from_paths paths) → $to_type ($to_paths paths)"
}
```

## Migration Strategy

### Phase 1: Create Configuration Infrastructure
1. Create `environments/` directory structure
2. Extract hardcoded paths into configuration files
3. Implement configuration loading system
4. Add entropy validation functions

### Phase 2: Refactor Scripts Incrementally  
1. Update `release_ops.sh` to use configuration loading
2. Modify container functions to use configurable paths
3. Update `safe-rp-ctl` command interface
4. Test each stage individually

### Phase 3: Environment-Specific Deployments
1. Create instance configs for local-dev, ci-build, staging, production
2. Test full pipeline with new configuration system
3. Validate IONOS deployment with type-4 staging config
4. Deploy to production with type-5 config

## Revolutionary Benefits of Deterministic Naming

### **True Type-5 Environments (2 Parameters Only!)**
✅ **Ship, Stage, Pre-prod, Production** all achieve **zero entropy**  
✅ **Deterministic naming** eliminates configuration guesswork  
✅ **Network isolation** with predictable patterns  
✅ **Container discovery** follows naming convention  

### **Multi-Dimensional Entropy Reduction**
✅ **Path Entropy**: Reduced to deployment root only  
✅ **Network Entropy**: Reduced to environment name only  
✅ **Container Entropy**: Reduced to environment name only  

### **Operational Benefits**
✅ **Easy Environment Addition** - Just specify `ENVIRONMENT="new-env"`  
✅ **Predictable Debugging** - Know exactly which containers/networks to check  
✅ **Simplified Deployment** - Same scripts work across all Type-5 environments  
✅ **Clear Separation** - Each environment completely isolated  

### **Current State vs. New System**

| Environment | Current Parameters | New Parameters | Entropy Reduction |
|-------------|-------------------|----------------|------------------|
| Ship | 8+ hardcoded values | **2 parameters** | **75%+ reduction** |
| Stage | 12+ hardcoded values | **2 parameters** | **85%+ reduction** |
| Pre-prod | 10+ hardcoded values | **2 parameters** | **80%+ reduction** |
| Production | 6+ hardcoded values | **2 parameters** | **65%+ reduction** |

This configuration system transforms our current hardcoded approach into a **deterministic, entropy-aware deployment pipeline** where adding new environments requires minimal configuration, and troubleshooting follows predictable patterns.