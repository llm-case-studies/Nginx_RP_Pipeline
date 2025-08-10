# Staging Box Configuration

This document defines the user structure, groups, and permissions required to replicate the IONOS production environment on the local staging box (Acer-HP.local) for testing purposes.

## IONOS Production Environment Structure

Based on the current pipeline configuration, the IONOS environment uses the following structure:

### Current Documented Users

The pipeline currently references these user accounts:

1. **deploy** - Used for stage environment deployments
   - Home: `/home/deploy/`
   - Stage deployment path: `/home/deploy/pre-prod-stage/proxyuser`
   - Purpose: Handles stage→preprod pipeline operations

2. **proxyuser** - Main proxy service account
   - Home: `/home/proxyuser/`
   - Preprod path: `/home/proxyuser/pre-prod`
   - Production path: `/home/proxyuser/NgNix-RP`
   - SSH access: `proxyuser@ionos-4c8g` (production), `proxyuser@preprod`
   - Purpose: Runs the production and preprod nginx proxy services

### Missing User Documentation

According to conversation history, the full IONOS structure includes **4 users**:
- `deploy`
- `nodeuser` ⚠️ **NOT YET DOCUMENTED**
- `pythonuser` ⚠️ **NOT YET DOCUMENTED**
- `proxyuser`

### Pipeline Set Groups

⚠️ **MISSING INFORMATION**: The conversation mentions "certain groups that indicate that a user is a part of our 'pipeline set'" but these groups are not currently documented in the codebase.

**Required Information to Complete This Document:**
1. What are the `nodeuser` and `pythonuser` accounts used for?
2. What are their home directories and deployment paths?
3. What groups indicate "pipeline set" membership?
4. What are the specific permissions and sudo access for each user?

## Environment-Specific Deployment Paths

Based on current configuration:

### Remote Environment Paths
- **stage**: `/home/deploy/pre-prod-stage/proxyuser` (deploy user context)
- **preprod**: `/home/proxyuser/pre-prod` (proxyuser account)
- **prod**: `/home/proxyuser/NgNix-RP` (proxyuser account)

### User Progression Through Pipeline
Current documented progression:
- **Stage Operations**: `deploy` user
- **Preprod→Prod Operations**: `proxyuser` user (same account, filesystem copy)

## Directory Structure and Permissions

### Stage Environment (`deploy` user)
```bash
/home/deploy/
├── pre-prod-stage/
│   └── proxyuser/          # Stage deployment directory
│       ├── nginx.conf
│       ├── conf.d/
│       ├── certs/
│       └── deployment-scripts/
```

### Production Environment (`proxyuser` user)
```bash
/home/proxyuser/
├── pre-prod/               # Preprod environment
│   ├── nginx.conf
│   ├── conf.d/
│   ├── certs/
│   └── deployment-scripts/
├── NgNix-RP/              # Production environment
│   ├── nginx.conf
│   ├── conf.d/
│   ├── certs/
│   └── deployment-scripts/
└── backup/                # Rollback configurations
```

## Local Staging Box Setup (Acer-HP.local)

To replicate this environment locally for testing:

### User Creation Script Template

```bash
#!/bin/bash
# staging-users-setup.sh
# Script to create IONOS-like user structure on Acer-HP.local

set -euo pipefail

echo "Creating staging users to match IONOS structure..."

# Create deploy user
sudo useradd -m -s /bin/bash deploy
echo "Created deploy user"

# Create nodeuser (PURPOSE TO BE DOCUMENTED)
# sudo useradd -m -s /bin/bash nodeuser
# echo "Created nodeuser"

# Create pythonuser (PURPOSE TO BE DOCUMENTED)  
# sudo useradd -m -s /bin/bash pythonuser
# echo "Created pythonuser"

# Create proxyuser
sudo useradd -m -s /bin/bash proxyuser
echo "Created proxyuser"

# Set up deploy user directories
sudo -u deploy mkdir -p /home/deploy/pre-prod-stage/proxyuser
echo "Created deploy directory structure"

# Set up proxyuser directories
sudo -u proxyuser mkdir -p /home/proxyuser/pre-prod
sudo -u proxyuser mkdir -p /home/proxyuser/NgNix-RP
sudo -u proxyuser mkdir -p /home/proxyuser/backup
echo "Created proxyuser directory structure"

# TODO: Add group creation and permissions when documented
# TODO: Add pipeline set group memberships when identified

echo "Basic user structure created. Still needed:"
echo "1. nodeuser and pythonuser purposes and setup"
echo "2. Pipeline set group definitions"
echo "3. User permissions and sudo access"
echo "4. SSH key setup for deployment access"
```

### Required Documentation Tasks

1. **SSH to IONOS** to document the actual user structure:
   ```bash
   # Extract user information
   cat /etc/passwd | grep -E "(deploy|nodeuser|pythonuser|proxyuser)"
   
   # Extract group information
   groups deploy nodeuser pythonuser proxyuser
   
   # Check pipeline set groups
   cat /etc/group | grep -i pipeline
   
   # Check sudo permissions
   sudo -l -U deploy
   sudo -l -U nodeuser  
   sudo -l -U pythonuser
   sudo -l -U proxyuser
   ```

2. **Document the missing users**:
   - What services do `nodeuser` and `pythonuser` run?
   - What deployment paths do they use?
   - How do they interact with the nginx pipeline?

3. **Document the "pipeline set" groups**:
   - What groups indicate pipeline set membership?
   - What permissions do these groups provide?
   - How are group memberships managed?

## Next Steps

1. ✅ Basic structure documented (deploy + proxyuser)
2. ⚠️ **Need to SSH to IONOS to extract missing information**
3. ⚠️ Complete user creation script with all 4 users
4. ⚠️ Document group structure and permissions
5. ⚠️ Test user replication script on Acer-HP.local
6. ⚠️ Validate pipeline operations work with replicated structure

---

**Status**: 🔴 **INCOMPLETE** - Missing critical information about nodeuser, pythonuser, and pipeline set groups.

**Required Action**: SSH access to IONOS needed to complete documentation.