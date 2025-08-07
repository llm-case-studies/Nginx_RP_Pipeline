# Pipeline Administrator's Guide

This guide provides instructions for the administrator responsible for operating the Nginx Reverse Proxy Pipeline.

## 1. Initial Setup

1.  Clone this repository to your local machine.
2.  Ensure all dependencies listed in `docs/REQUIREMENTS.md` are installed.
3.  For local development, follow the `mkcert` instructions in `REQUIREMENTS.md` to set up a local Certificate Authority.

## 2. Core Workflows

### 2.1. Safe Pipeline Workflow with Validation

The enhanced pipeline provides validation at every stage to prevent broken deployments.

#### Standard Deployment Flow
1.  **Fetch Production State:**
    ```bash
    ./scripts/safe-rp-ctl fetch-seed
    ```
    Creates exact production replica in `workspace/seed/` with all certificates.

2.  **Create Integration Workspace:**
    ```bash
    ./scripts/safe-rp-ctl init-wip
    ```
    Copies seed to `workspace/wip/` for safe integration.

3.  **Add New Applications:**
    - Place `.zip` bundles in `intake/` directory
    - Add certificates to project `certs/` directory
    - Run integration build (future enhancement)

4.  **Handle Integration Issues (if needed):**
    - Manually edit files in `workspace/wip/`
    - Test with `./scripts/safe-rp-ctl start-wip`
    - **Lock workspace when working:**
      ```bash
      ./scripts/safe-rp-ctl lock-wip "Fixed port conflicts + routing"
      ```

5.  **Build Clean Runtime:**
    ```bash
    ./scripts/safe-rp-ctl build-prep
    ```
    ✅ **Validates WIP completeness** - certificates, configs, nginx syntax

6.  **Build Deployment Package:**
    ```bash
    ./scripts/safe-rp-ctl build-ship
    ```
    ✅ **Validates prep runtime** - creates zero-entropy deployment package

7.  **Deploy to Environments:**
    Copy ship package to target environment and run deployment scripts.

### 2.2. Rolling Back a Failed Deployment

If a deployment introduces issues, you can immediately roll back to the last known-good configuration.

1.  **Run Rollback Command:**
    ```bash
    ./proxy-container.sh rollback
    ```
    The script will restore the previous configuration from the `backup/` directory and reload Nginx.

## 3. Command Reference

### Core Pipeline Commands
- `./scripts/safe-rp-ctl fetch-seed` - Fetch production snapshot to workspace/seed
- `./scripts/safe-rp-ctl init-wip` - Initialize work-in-progress from seed
- `./scripts/safe-rp-ctl build-prep` - Build clean runtime (with validation)
- `./scripts/safe-rp-ctl build-ship` - Build deployment package (with validation)

### Environment Management  
- `./scripts/safe-rp-ctl start-seed` - Start production replica (port 8080)
- `./scripts/safe-rp-ctl start-wip` - Start development workspace (port 8081)
- `./scripts/safe-rp-ctl start-prep` - Start clean build (port 8082)
- `./scripts/safe-rp-ctl start-ship` - Start final verification (port 8083)
- `./scripts/safe-rp-ctl start-env <env>` - Start any environment (ship/stage/preprod/prod)

### WIP Workspace Management
- `./scripts/safe-rp-ctl lock-wip "reason"` - Lock WIP workspace to protect manual fixes
- `./scripts/safe-rp-ctl unlock-wip` - Unlock WIP workspace to allow modifications
- `./scripts/safe-rp-ctl wip-status` - Show WIP workspace lock status and details

### Utilities
- `./scripts/safe-rp-ctl stop-all` - Stop all local containers
- `./scripts/safe-rp-ctl ensure-external` - Start external services
- `./scripts/safe-rp-ctl list-releases` - Show available releases
- `./scripts/safe-rp-ctl describe-release <dir>` - Show release details

### Validation Features
- ✅ **Automatic validation** in build-prep and build-ship
- ✅ **Certificate verification** at every stage  
- ✅ **Nginx syntax checking** before deployment
- ✅ **Completeness checks** prevent broken packages
- ✅ **Lock protection** preserves manual integration work