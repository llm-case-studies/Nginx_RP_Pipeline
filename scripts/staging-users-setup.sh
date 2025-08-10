#!/bin/bash
# staging-users-setup.sh
# Script to create IONOS-like user structure on Acer-HP.local staging box
#
# Usage: sudo ./scripts/staging-users-setup.sh
#
# This script replicates the 4-user IONOS production structure locally
# for testing pipeline operations in a production-like environment.

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Setting up IONOS-like user structure on staging box (Acer-HP.local)"
log_warning "This will create 4 users: deploy, nodeuser, pythonuser, proxyuser"

# Function to create user if it doesn't exist
create_user() {
    local username="$1"
    local description="$2"
    
    if id "$username" &>/dev/null; then
        log_warning "User $username already exists, skipping creation"
    else
        useradd -m -s /bin/bash "$username"
        log_success "Created user: $username ($description)"
    fi
}

# Function to create directory structure
create_directory() {
    local path="$1"
    local owner="$2"
    local description="$3"
    
    if [[ ! -d "$path" ]]; then
        mkdir -p "$path"
        chown "$owner:$owner" "$path"
        chmod 755 "$path"
        log_success "Created directory: $path ($description)"
    else
        log_warning "Directory already exists: $path"
    fi
}

echo
log_info "Creating users..."

# 1. Create deploy user - handles stage environment deployments
create_user "deploy" "Stage deployment user"

# 2. Create nodeuser - handles Node.js application deployments
create_user "nodeuser" "Node.js application deployment user"

# 3. Create pythonuser - handles Python application deployments  
create_user "pythonuser" "Python application deployment user"

# 4. Create proxyuser - runs nginx proxy services
create_user "proxyuser" "Nginx proxy service user"

echo
log_info "Setting up directory structures..."

# Deploy user directories
create_directory "/home/deploy/pre-prod-stage" "deploy" "Stage deployment workspace"
create_directory "/home/deploy/pre-prod-stage/proxyuser" "deploy" "Stage proxy deployment target"

# NodeUser directories (TODO: Define based on IONOS structure)
create_directory "/home/nodeuser/applications" "nodeuser" "Node.js application directory"
log_warning "nodeuser directory structure needs completion based on IONOS inspection"

# PythonUser directories (TODO: Define based on IONOS structure)
create_directory "/home/pythonuser/applications" "pythonuser" "Python application directory" 
log_warning "pythonuser directory structure needs completion based on IONOS inspection"

# ProxyUser directories - main proxy service directories
create_directory "/home/proxyuser/pre-prod" "proxyuser" "Preprod proxy environment"
create_directory "/home/proxyuser/NgNix-RP" "proxyuser" "Production proxy environment"
create_directory "/home/proxyuser/backup" "proxyuser" "Proxy configuration backups"

echo
log_info "Setting up basic permissions..."

# Set basic directory permissions
chmod 755 /home/deploy/pre-prod-stage
chmod 755 /home/deploy/pre-prod-stage/proxyuser
chmod 755 /home/proxyuser/pre-prod
chmod 755 /home/proxyuser/NgNix-RP
chmod 755 /home/proxyuser/backup

echo
log_warning "INCOMPLETE SETUP - The following still needs to be configured:"
echo "  1. Pipeline set groups (not yet documented)"
echo "  2. User group memberships for pipeline operations"
echo "  3. Sudo permissions for deployment operations"
echo "  4. SSH key setup for inter-user deployment access"
echo "  5. nodeuser and pythonuser specific directory structures"
echo "  6. Application-specific permissions and service configurations"

echo
log_info "To complete the setup, the following information is needed from IONOS:"

cat << 'EOF'

# SSH to IONOS and run these commands to extract user structure:

# 1. Get user account information
cat /etc/passwd | grep -E "(deploy|nodeuser|pythonuser|proxyuser)"

# 2. Get group memberships  
groups deploy
groups nodeuser
groups pythonuser
groups proxyuser

# 3. Check for pipeline set groups
cat /etc/group | grep -i pipeline

# 4. Check sudo permissions
sudo -l -U deploy
sudo -l -U nodeuser
sudo -l -U pythonuser  
sudo -l -U proxyuser

# 5. Check home directory structures
ls -la /home/deploy/
ls -la /home/nodeuser/
ls -la /home/pythonuser/
ls -la /home/proxyuser/

# 6. Check service configurations
systemctl list-units --user --all | grep -E "(nginx|node|python)"

EOF

echo
log_success "Basic user structure created on staging box"
log_info "Users created: deploy, nodeuser, pythonuser, proxyuser"
log_info "Basic directories created for deploy and proxyuser"
log_warning "Run 'scripts/staging-users-complete.sh' after documenting IONOS structure"

echo
log_info "Next steps:"
echo "  1. SSH to IONOS and extract full user/group information"
echo "  2. Update docs/STAGING_BOX_CONFIGURATION.md with findings"  
echo "  3. Run staging-users-complete.sh to finish setup"
echo "  4. Test pipeline operations on Acer-HP.local staging environment"