# Acer-HL Local Staging Environment Setup

## System Analysis & Readiness Assessment

**Target System**: `acer-hl.local` (funhome@acer-hl.local)  
**Date**: 2025-08-10  
**Purpose**: Local staging environment for IONOS pipeline emulation

### ✅ System Specifications & Status

**Operating System**:
```
Linux Acer-HL 6.1.0-37-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.140-1 (2025-05-22) x86_64 GNU/Linux
Debian GNU/Linux 12 (bookworm)
```

**Resources**:
- **CPU**: x86_64 architecture
- **Memory**: 7.6GB total, 6.2GB available  
- **Disk**: 233GB total, 184GB available (18% used)
- **Swap**: 975MB available

**Existing User**: `funhome`
- **Groups**: `funhome root cdrom sudo audio video plugdev users netdev ssl-cert docker`
- **Privileges**: Full sudo access, Docker group membership
- **Status**: ✅ Ready for administrative tasks

### ✅ Installed Software Status

| Tool | Version | Status | Notes |
|------|---------|--------|-------|
| **Docker** | 20.10.24+dfsg1 | ✅ Working | Service active, funhome in docker group |
| **Git** | 2.39.5 | ✅ Installed | Version control ready |
| **Curl** | 7.88.1 | ✅ Installed | HTTP client available |
| **Wget** | 1.21.3 | ✅ Installed | File downloads ready |
| **Bash** | Available | ✅ Installed | Scripting environment ready |
| **Sudo** | Available | ✅ Installed | Administrative access ready |
| **flock** | Available | ✅ Installed | File locking for deployments |
| **nginx** | Not installed | ✅ OK | Will use Docker containers |
| **rsync** | **MISSING** | ⚠️ **NEEDS INSTALL** | Required for file synchronization |

### ⚠️ Missing Dependencies

**Required Installation**:
1. **rsync** - Essential for deployment file synchronization
   - Used by promotion scripts between environments
   - Required for atomic file operations
   - Install command: `sudo apt install -y rsync`

**Optional Enhancements**:
- `htop` - Better process monitoring
- `tree` - Directory structure visualization  
- `jq` - JSON processing for deployment manifests
- `mkcert` - Local SSL certificate generation (if needed)

### 🏗️ Current State Assessment

**Existing Users**: Only `alex` and `funhome` present
- ✅ No pipeline users exist (clean slate)
- ✅ No conflicting group memberships
- ✅ No existing deployment structures

**Network**: SSH access working
- ✅ Key-based authentication established
- ✅ No firewall blocking Docker ports
- ✅ Local network connectivity confirmed

**Docker Environment**: Fully operational
- ✅ Docker daemon running
- ✅ No existing containers
- ✅ User has Docker permissions
- ✅ Ready for nginx container deployment

## 📋 Implementation Plan

### Phase 1: System Dependencies (5 minutes)
1. **Install rsync**: Essential for deployment synchronization
2. **Verify installations**: Confirm all tools working
3. **Optional tools**: Install monitoring/utility packages

### Phase 2: Pipeline User Setup (10 minutes)
1. **Create pipeline groups**:
   - `pipeline-all` (base access)
   - `pipeline-stage` (staging access)
   - `pipeline-prod` (production access)  
   - `pronunco-style` (standards enforcement)

2. **Create pipeline users**:
   - `deploy` (staging operations, Docker access)
   - `nodeuser` (Node.js applications) 
   - `pythonuser` (Python applications)
   - `proxyuser` (nginx proxy operations, Docker access)

3. **Set up directory structures**:
   - `/home/deploy/Live-Mirror/` (git operations)
   - `/home/deploy/pre-prod-stage/proxyuser/` (staging deployment)
   - `/home/proxyuser/NgNx-RP/` (production emulation)
   - `/home/proxyuser/pre-prod/` (preprod environment)
   - `/home/nodeuser/nodejs-apps/` (Node.js deployments)
   - `/home/pythonuser/python-apps/` (Python deployments)

### Phase 3: Validation & Testing (15 minutes)
1. **Run validation scripts**:
   - Verify user/group creation
   - Test directory permissions
   - Validate pipeline access logic

2. **Test pipeline operations**:
   - Docker access for deploy/proxyuser
   - Directory access patterns
   - Group membership detection

3. **Integration testing**:
   - Deploy test nginx container
   - Verify port assignments
   - Test promotion mechanics

### Phase 4: Documentation & Handoff (10 minutes)
1. **Document actual setup**: Record any deviations or issues
2. **Create operational notes**: Commands for common tasks
3. **Update team documentation**: Share access details and procedures

## 🚀 Execution Commands

### Install Dependencies
```bash
ssh funhome@acer-hl.local "sudo apt update && sudo apt install -y rsync htop tree jq"
```

### Deploy Setup Scripts
```bash
# Transfer setup script
scp docs/LOCAL_EMULATION_USERS_GROUPS.md funhome@acer-hl.local:/tmp/

# Extract and run setup script
ssh funhome@acer-hl.local "sudo bash" << 'EOF'
# [Setup script content will be extracted and executed]
EOF
```

### Run Validation
```bash
ssh funhome@acer-hl.local "bash /usr/local/bin/validate-ionos-emulation.sh"
```

## 📊 Success Criteria

**✅ System Ready When**:
1. All 4 pipeline users created with correct group memberships
2. Directory structures match IONOS production layout
3. Pipeline access detection logic working correctly
4. Docker containers can be deployed by appropriate users
5. File permissions and ownership properly configured
6. Validation scripts pass all checks

**📈 Metrics to Track**:
- Setup time: Target < 30 minutes total
- Validation pass rate: 100% required
- Docker container startup: < 30 seconds
- User switching: No permission errors

## 🔄 Rollback Plan

If issues occur during setup:

1. **User Cleanup**: Remove created users and groups
   ```bash
   for user in deploy nodeuser pythonuser proxyuser; do
       sudo userdel -r $user 2>/dev/null || true
   done
   ```

2. **Group Cleanup**: Remove pipeline groups
   ```bash
   for group in pipeline-all pipeline-stage pipeline-prod pronunco-style; do
       sudo groupdel $group 2>/dev/null || true
   done
   ```

3. **Directory Cleanup**: Remove any created directories
   ```bash
   sudo rm -rf /opt/pronunco-api
   ```

## 👥 Team Communication

**Slack/Discord Update Template**:
```
🏗️ Local Staging Setup - acer-hl.local

Status: [IN_PROGRESS|COMPLETED|BLOCKED]
Progress: [Phase X of 4]
ETA: [XX minutes remaining]

✅ Completed: [list items]
⚠️  Issues: [any problems encountered]
🔄 Next: [upcoming actions]

Access: ssh funhome@acer-hl.local
Docs: docs/ACER_HL_LOCAL_STAGING_SETUP.md
```

**After Completion**:
- [ ] Share SSH access details securely
- [ ] Document any configuration variations  
- [ ] Schedule team walkthrough/demo
- [ ] Update main project documentation

---

**Document Status**: ✅ Ready for implementation  
**Next Action**: Install dependencies and execute setup scripts  
**Owner**: [Current user]  
**Review Required**: After Phase 3 validation