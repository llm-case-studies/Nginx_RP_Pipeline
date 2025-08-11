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

# Install missing dependencies first
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update
apt install -y rsync htop tree jq
echo -e "${GREEN}✅ Dependencies installed${NC}"

# Create pipeline groups first
echo -e "${YELLOW}📋 Creating pipeline groups...${NC}"
groupadd -f pipeline-all
groupadd -f pipeline-stage
groupadd -f pipeline-prod
groupadd -f pronunco-style
echo -e "${GREEN}✅ Pipeline groups created${NC}"

# Create users and assign to groups
echo -e "${YELLOW}👤 Creating deploy user...${NC}"
useradd -m -s /bin/bash -G docker,pipeline-all,pipeline-stage,pronunco-style deploy 2>/dev/null || true
echo -e "${GREEN}✅ Deploy user created${NC}"

echo -e "${YELLOW}👤 Creating nodeuser...${NC}"
useradd -m -s /bin/bash -G pipeline-all,pipeline-prod,pronunco-style nodeuser 2>/dev/null || true
echo -e "${GREEN}✅ NodeUser created${NC}"

echo -e "${YELLOW}👤 Creating pythonuser...${NC}"
useradd -m -s /bin/bash -G pipeline-all,pipeline-prod,pronunco-style pythonuser 2>/dev/null || true
echo -e "${GREEN}✅ PythonUser created${NC}"

echo -e "${YELLOW}👤 Creating proxyuser...${NC}"
useradd -m -s /bin/bash -G users,docker,pipeline-all,pipeline-prod,pronunco-style proxyuser 2>/dev/null || true
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
mkdir -p /opt/pronunco-api
chown deploy:deploy /opt/pronunco-api

echo -e "${GREEN}✅ Deployment paths configured${NC}"

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