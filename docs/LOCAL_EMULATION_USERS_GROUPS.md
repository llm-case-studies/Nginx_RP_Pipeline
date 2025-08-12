# Local Emulation: User & Group Setup Guide

## Overview

This document provides comprehensive instructions for setting up user accounts and group memberships on local development/staging systems to emulate the IONOS production environment structure. This enables safe testing of deployment scripts, pipeline operations, and user permission flows before executing on production.

## IONOS Production Environment Reference

### User Accounts & Group Memberships

Based on analysis of the production IONOS server (`proxy-4c-8g-ionos`):

```bash
# Production group memberships (from: groups deploy nodeuser pythonuser proxyuser)
deploy      : deploy docker pipeline-all pipeline-stage pronunco-style
nodeuser    : nodeuser pipeline-all pipeline-prod pronunco-style
pythonuser  : pythonuser pipeline-all pipeline-prod pronunco-style
proxyuser   : proxyuser users docker pipeline-all pipeline-prod pronunco-style
```

### Pipeline Access Control Logic

```bash
# Pipeline team identification
if groups $USER | grep -q "pipeline-"; then
    echo "User $USER is part of pipeline team"
    
    if groups $USER | grep -q "pipeline-stage"; then
        echo "User has staging deployment access"
    fi
    
    if groups $USER | grep -q "pipeline-prod"; then
        echo "User has production deployment access"
    fi
fi
```

### Directory Structure & Ownership

```
/home/deploy/
├── Live-Mirror/                    # Git-based deployment orchestration
├── lib/                           # Deployment libraries and logging
└── pre-prod-stage/                # Staging environment files
    └── proxyuser/                 # Stage deployment directory

/home/proxyuser/
├── NgNX-RP/                       # Production nginx configuration
│   ├── nginx.conf
│   ├── certs/                     # SSL certificates (600/644 permissions)
│   └── deployment-history.log
├── pre-prod/                      # Pre-production environment
└── deployment-scripts/

/home/nodeuser/
├── nodejs-apps/                   # Node.js application deployments
│   └── pronunco-api/              # Application-specific directories
└── logs/                          # Application log files

/home/pythonuser/
├── python-apps/                   # Python application deployments
└── logs/                          # Application log files
```

## Local Emulation Setup Scripts

### 1. Primary Setup Script

Create `/usr/local/bin/setup-ionos-emulation.sh`:

```bash
#!/bin/bash
# setup-ionos-emulation.sh
# Creates IONOS-like user/group structure for local development

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Setting up IONOS emulation environment...${NC}"

# Create pipeline groups first
echo -e "${YELLOW}📋 Creating pipeline groups...${NC}"
sudo groupadd -f pipeline-all
sudo groupadd -f pipeline-stage
sudo groupadd -f pipeline-prod
sudo groupadd -f pronunco-style
echo -e "${GREEN}✅ Pipeline groups created${NC}"

# Create users and assign to groups
echo -e "${YELLOW}👤 Creating deploy user...${NC}"
sudo useradd -m -s /bin/bash -G docker,pipeline-all,pipeline-stage,pronunco-style deploy 2>/dev/null || true
echo -e "${GREEN}✅ Deploy user created${NC}"

echo -e "${YELLOW}👤 Creating nodeuser...${NC}"
sudo useradd -m -s /bin/bash -G pipeline-all,pipeline-prod,pronunco-style nodeuser 2>/dev/null || true
echo -e "${GREEN}✅ NodeUser created${NC}"

echo -e "${YELLOW}👤 Creating pythonuser...${NC}"
sudo useradd -m -s /bin/bash -G pipeline-all,pipeline-prod,pronunco-style pythonuser 2>/dev/null || true
echo -e "${GREEN}✅ PythonUser created${NC}"

echo -e "${YELLOW}👤 Creating proxyuser...${NC}"
sudo useradd -m -s /bin/bash -G users,docker,pipeline-all,pipeline-prod,pronunco-style proxyuser 2>/dev/null || true
echo -e "${GREEN}✅ ProxyUser created${NC}"

# Create directory structures
echo -e "${YELLOW}📁 Creating directory structures...${NC}"

# Deploy user directories
sudo -u deploy mkdir -p /home/deploy/Live-Mirror
sudo -u deploy mkdir -p /home/deploy/lib
sudo -u deploy mkdir -p /home/deploy/pre-prod-stage/proxyuser

# ProxyUser directories  
sudo -u proxyuser mkdir -p /home/proxyuser/NgNx-RP/certs
sudo -u proxyuser mkdir -p /home/proxyuser/pre-prod
sudo -u proxyuser mkdir -p /home/proxyuser/deployment-scripts
sudo -u proxyuser mkdir -p /home/proxyuser/backup

# NodeUser directories
sudo -u nodeuser mkdir -p /home/nodeuser/nodejs-apps
sudo -u nodeuser mkdir -p /home/nodeuser/logs

# PythonUser directories
sudo -u pythonuser mkdir -p /home/pythonuser/python-apps  
sudo -u pythonuser mkdir -p /home/pythonuser/logs

echo -e "${GREEN}✅ Directory structures created${NC}"

# Set up deployment paths to match IONOS configuration
echo -e "${YELLOW}🔗 Creating deployment path compatibility...${NC}"

# Create compatibility paths for deployment scripts
sudo mkdir -p /opt/pronunco-api
sudo chown deploy:deploy /opt/pronunco-api

echo -e "${GREEN}✅ Deployment paths configured${NC}"

# Set up SSH access for pipeline users
echo -e "${YELLOW}🔑 Setting up SSH access for pipeline users...${NC}"

# Check if current user has SSH keys to copy
if [[ -f "/home/$SUDO_USER/.ssh/authorized_keys" ]]; then
    echo -e "${GREEN}Found SSH keys from user: $SUDO_USER${NC}"
    
    for user in deploy nodeuser pythonuser proxyuser; do
        echo "  Setting up SSH for: $user"
        
        # Create .ssh directory
        sudo -u $user mkdir -p /home/$user/.ssh
        sudo -u $user chmod 700 /home/$user/.ssh
        
        # Copy authorized_keys from the user who ran sudo
        sudo cp "/home/$SUDO_USER/.ssh/authorized_keys" "/home/$user/.ssh/authorized_keys"
        sudo chown $user:$user "/home/$user/.ssh/authorized_keys"
        sudo chmod 600 "/home/$user/.ssh/authorized_keys"
        
        echo "  ✅ SSH configured for $user"
    done
    
    echo -e "${GREEN}✅ SSH access configured for all pipeline users${NC}"
else
    echo -e "${YELLOW}⚠️  Warning: No SSH keys found for $SUDO_USER${NC}"
    echo -e "${YELLOW}   Creating empty .ssh directories for pipeline users${NC}"
    
    for user in deploy nodeuser pythonuser proxyuser; do
        echo "  Creating SSH directory for: $user"
        
        # Create .ssh directory only
        sudo -u $user mkdir -p /home/$user/.ssh
        sudo -u $user chmod 700 /home/$user/.ssh
        
        # Create empty authorized_keys file
        sudo -u $user touch /home/$user/.ssh/authorized_keys
        sudo -u $user chmod 600 /home/$user/.ssh/authorized_keys
        
        echo "  ✅ SSH directory created for $user (keys need manual setup)"
    done
    
    echo -e "${YELLOW}⚠️  Manual SSH key setup required:${NC}"
    echo "   For each user, copy SSH public keys to:"
    echo "   /home/[user]/.ssh/authorized_keys"
fi

# Verify setup
echo -e "${YELLOW}🔍 Verifying user group memberships...${NC}"
for user in deploy nodeuser pythonuser proxyuser; do
    echo -e "${GREEN}$user${NC}: $(groups $user 2>/dev/null | cut -d: -f2)"
done

echo -e "${GREEN}🎉 IONOS emulation setup complete!${NC}"
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "   1. Run pipeline validation tests"
echo "   2. Test deployment script permissions" 
echo "   3. Verify group access control logic"
echo "   4. Test directory ownership and permissions"
```

### 2. Validation Script

Create `/usr/local/bin/validate-ionos-emulation.sh`:

```bash
#!/bin/bash
# validate-ionos-emulation.sh
# Validates that local emulation matches IONOS production structure

set -euo pipefail

ERRORS=0

echo "🔍 Validating IONOS emulation setup..."

# Check users exist
for user in deploy nodeuser pythonuser proxyuser; do
    if id "$user" &>/dev/null; then
        echo "✅ User $user exists"
    else
        echo "❌ User $user missing"
        ((ERRORS++))
    fi
done

# Check groups exist
for group in pipeline-all pipeline-stage pipeline-prod pronunco-style; do
    if getent group "$group" &>/dev/null; then
        echo "✅ Group $group exists"
    else
        echo "❌ Group $group missing"
        ((ERRORS++))
    fi
done

# Check group memberships
declare -A expected_groups=(
    ["deploy"]="deploy docker pipeline-all pipeline-stage pronunco-style"
    ["nodeuser"]="nodeuser pipeline-all pipeline-prod pronunco-style"  
    ["pythonuser"]="pythonuser pipeline-all pipeline-prod pronunco-style"
    ["proxyuser"]="proxyuser users docker pipeline-all pipeline-prod pronunco-style"
)

for user in "${!expected_groups[@]}"; do
    actual_groups=$(groups "$user" 2>/dev/null | cut -d: -f2 | tr ' ' '\n' | sort | tr '\n' ' ')
    expected="${expected_groups[$user]}"
    
    for group in $expected; do
        if echo "$actual_groups" | grep -q "\b$group\b"; then
            echo "✅ $user is in $group"
        else
            echo "❌ $user missing from $group"
            ((ERRORS++))
        fi
    done
done

# Check directory structure
declare -A expected_dirs=(
    ["/home/deploy/Live-Mirror"]="deploy:deploy"
    ["/home/deploy/pre-prod-stage/proxyuser"]="deploy:deploy"
    ["/home/proxyuser/NgNx-RP"]="proxyuser:proxyuser"
    ["/home/proxyuser/pre-prod"]="proxyuser:proxyuser"
    ["/home/nodeuser/nodejs-apps"]="nodeuser:nodeuser"
    ["/home/pythonuser/python-apps"]="pythonuser:pythonuser"
)

for dir in "${!expected_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        owner=$(stat -c %U:%G "$dir")
        expected="${expected_dirs[$dir]}"
        if [[ "$owner" == "$expected" ]]; then
            echo "✅ $dir exists with correct ownership ($owner)"
        else
            echo "❌ $dir has incorrect ownership. Expected: $expected, Actual: $owner"
            ((ERRORS++))
        fi
    else
        echo "❌ Directory $dir missing"
        ((ERRORS++))
    fi
done

# Test pipeline team logic
echo ""
echo "🧪 Testing pipeline team detection logic..."
for user in deploy nodeuser pythonuser proxyuser; do
    if groups "$user" | grep -q "pipeline-"; then
        echo "✅ $user detected as pipeline team member"
        
        if groups "$user" | grep -q "pipeline-stage"; then
            echo "   └─ ✅ $user has staging access"
        fi
        
        if groups "$user" | grep -q "pipeline-prod"; then
            echo "   └─ ✅ $user has production access"
        fi
    else
        echo "❌ $user not detected as pipeline team member"
        ((ERRORS++))
    fi
done

# Test SSH directory setup
echo ""
echo "🔑 Testing SSH access setup..."
for user in deploy nodeuser pythonuser proxyuser; do
    if [[ -d "/home/$user/.ssh" ]]; then
        ssh_perms=$(stat -c %a "/home/$user/.ssh")
        if [[ "$ssh_perms" == "700" ]]; then
            echo "✅ $user has .ssh directory with correct permissions (700)"
        else
            echo "❌ $user .ssh directory has incorrect permissions: $ssh_perms (should be 700)"
            ((ERRORS++))
        fi
        
        if [[ -f "/home/$user/.ssh/authorized_keys" ]]; then
            keys_perms=$(stat -c %a "/home/$user/.ssh/authorized_keys")
            if [[ "$keys_perms" == "600" ]]; then
                echo "✅ $user has authorized_keys with correct permissions (600)"
                
                # Check if file has content (not empty)
                if [[ -s "/home/$user/.ssh/authorized_keys" ]]; then
                    echo "   └─ ✅ authorized_keys contains SSH keys"
                else
                    echo "   └─ ⚠️  authorized_keys is empty (manual SSH key setup needed)"
                fi
            else
                echo "❌ $user authorized_keys has incorrect permissions: $keys_perms (should be 600)"
                ((ERRORS++))
            fi
        else
            echo "❌ $user missing authorized_keys file"
            ((ERRORS++))
        fi
    else
        echo "❌ $user missing .ssh directory"
        ((ERRORS++))
    fi
done

echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo "🎉 All validation checks passed! Local emulation matches IONOS structure."
    exit 0
else
    echo "❌ $ERRORS validation errors found. Please fix before proceeding."
    exit 1
fi
```

### 3. Pipeline Access Test Script

Create `/usr/local/bin/test-pipeline-access.sh`:

```bash
#!/bin/bash
# test-pipeline-access.sh
# Tests pipeline access control logic and permissions

set -euo pipefail

echo "🧪 Testing pipeline access control..."

# Function to test user permissions
test_user_access() {
    local user=$1
    echo "Testing access for user: $user"
    
    # Test pipeline team membership
    sudo -u "$user" bash -c '
        if groups | grep -q "pipeline-"; then
            echo "  ✅ Pipeline team member detected"
            
            if groups | grep -q "pipeline-stage"; then
                echo "  ✅ Staging access confirmed"
            else
                echo "  ℹ️  No staging access (expected for prod-only users)"
            fi
            
            if groups | grep -q "pipeline-prod"; then
                echo "  ✅ Production access confirmed"
            else
                echo "  ℹ️  No production access (expected for staging-only users)"
            fi
        else
            echo "  ❌ Not detected as pipeline team member"
            exit 1
        fi
    '
    
    # Test Docker access (for users that should have it)
    if [[ "$user" == "deploy" || "$user" == "proxyuser" ]]; then
        if sudo -u "$user" groups | grep -q "docker"; then
            echo "  ✅ Docker access confirmed"
        else
            echo "  ❌ Missing Docker access"
            exit 1
        fi
    fi
    
    echo ""
}

# Test all users
for user in deploy nodeuser pythonuser proxyuser; do
    test_user_access "$user"
done

echo "🎉 All pipeline access tests passed!"
```

## Usage Instructions

### 1. Initial Setup

```bash
# Download and make executable
sudo curl -o /usr/local/bin/setup-ionos-emulation.sh https://example.com/setup-ionos-emulation.sh
sudo chmod +x /usr/local/bin/setup-ionos-emulation.sh

# Run setup
sudo /usr/local/bin/setup-ionos-emulation.sh
```

### 2. Validation

```bash
# Download validation script
sudo curl -o /usr/local/bin/validate-ionos-emulation.sh https://example.com/validate-ionos-emulation.sh
sudo chmod +x /usr/local/bin/validate-ionos-emulation.sh

# Run validation
/usr/local/bin/validate-ionos-emulation.sh
```

### 3. Testing Pipeline Operations

```bash
# Test deployment operations as deploy user
sudo -u deploy bash -c 'cd /home/deploy/Live-Mirror && echo "Testing deploy user access"'

# Test application operations as nodeuser  
sudo -u nodeuser bash -c 'cd /home/nodeuser/nodejs-apps && echo "Testing nodeuser access"'

# Test proxy operations as proxyuser
sudo -u proxyuser bash -c 'cd /home/proxyuser/NgNx-RP && echo "Testing proxyuser access"'
```

## Integration with Development Workflow

### Local Pipeline Testing

This user structure enables complete local testing of deployment scripts:

```bash
# Test deployment script as deploy user
sudo -u deploy ./deploy-scripts/deploy-to-stage.sh

# Test promotion script between users
sudo -u deploy ./deploy-scripts/promote-stage-to-preprod.sh
sudo -u proxyuser ./deploy-scripts/promote-preprod-to-prod.sh

# Test rollback operations
sudo -u proxyuser ./deploy-scripts/rollback-production.sh
```

### Nginx_RP_Pipeline Integration

The local emulation integrates with the existing pipeline system:

```bash
# Start local environments with user emulation
./scripts/safe-rp-ctl start-wip    # Development (port 8081)
./scripts/safe-rp-ctl start-prep   # Staging emulation (port 8082) 
./scripts/safe-rp-ctl start-ship   # Production emulation (port 8083)
```

## Cleanup & Removal

If needed, remove the emulation environment:

```bash
#!/bin/bash
# cleanup-ionos-emulation.sh

echo "🧹 Cleaning up IONOS emulation environment..."

# Remove users
for user in deploy nodeuser pythonuser proxyuser; do
    sudo userdel -r "$user" 2>/dev/null || true
    echo "Removed user: $user"
done

# Remove groups  
for group in pipeline-all pipeline-stage pipeline-prod pronunco-style; do
    sudo groupdel "$group" 2>/dev/null || true
    echo "Removed group: $group"
done

# Clean up directories
sudo rm -rf /opt/pronunco-api

echo "✅ Cleanup complete"
```

## Security Considerations

1. **Isolation**: Local emulation users should not have sudo privileges by default
2. **SSH Keys**: Do not copy production SSH keys to local emulation
3. **Secrets**: Use dummy/test certificates and secrets in local environment
4. **Network**: Ensure local services don't conflict with production ports
5. **Cleanup**: Regularly clean up test environments to prevent resource accumulation

## Troubleshooting

### Common Issues

1. **"User already exists"**: Use `-f` flag with `useradd` or check if user exists first
2. **"Permission denied"**: Ensure scripts are run with appropriate sudo privileges  
3. **"Group not found"**: Create groups before assigning users to them
4. **"Directory exists"**: Use `mkdir -p` to avoid errors with existing directories

### Verification Commands

```bash
# Check user group memberships
groups deploy nodeuser pythonuser proxyuser

# Verify directory ownership  
ls -la /home/*/

# Test pipeline detection logic
for user in deploy nodeuser pythonuser proxyuser; do
    sudo -u $user bash -c 'if groups | grep -q "pipeline-"; then echo "$USER is pipeline member"; fi'
done
```

---

**Status**: ✅ **Complete** - Ready for implementation and testing

**Dependencies**: 
- Docker installed for deploy/proxyuser users
- sudo access for initial setup
- bash shell for all pipeline users

**Next Steps**:
1. Implement setup scripts on local development systems
2. Test deployment script permissions and access control
3. Validate promotion/rollback procedures in local environment
4. Document any environment-specific modifications needed