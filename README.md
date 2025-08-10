# Nginx Reverse Proxy Deployment Pipeline

This repository contains the infrastructure-as-code for deploying and managing the Nginx reverse proxy for the PronunCo project and other associated services. It is designed to be a safe, reliable, and automated pipeline for managing critical web traffic infrastructure.

This project was intentionally separated from the main application repository (`PronunCo`) to enforce a clean separation between application code and infrastructure code.

## Project Goals

- **Automation:** To automate the entire process of testing and deploying Nginx configurations.
- **Safety:** To implement robust safety checks, including configuration validation and automated health checks, to prevent production outages.
- **Maintainability:** To use a modular, decomposed configuration structure (`conf.d`) that is easy to read and manage.
- **High-Fidelity Local Development:** To provide a local development experience that perfectly mirrors the production environment, including local SSL support via `mkcert`.
- **Zero-Entropy Deployments:** Self-contained deployment packages with deterministic naming and configuration.

## Pipeline Architecture

The pipeline follows a **seed→wip→prep→ship** flow:

- **seed**: Production replica workspace (read-only reference)
- **wip**: Development workspace (manual integration and testing)  
- **prep**: Clean runtime (automated build from wip)
- **ship**: Self-contained deployment package (zero-entropy, deterministic)

## Documentation

- **[Architecture](./docs/ARCHITECTURE.md):** A high-level overview of the pipeline's components and workflow.
- **[Requirements](./docs/REQUIREMENTS.md):** The technical requirements for running the pipeline.
- **[User Guide](./docs/USER_GUIDE.md):** Instructions for application developers who need to host their apps behind the proxy.
- **[Admin Guide](./docs/ADMIN_GUIDE.md):** Instructions for the administrator who operates the pipeline.
- **[Remote Deployment Discussion](./docs/REMOTE_DEPLOYMENT_ARCHITECTURE_DISCUSSION.md):** Analysis of deployment architecture options for remote environments.

## Getting Started

1. **Clone this repository.**
2. **Install the required software** (see [Requirements](./docs/REQUIREMENTS.md)).
3. **Run the test suite** to validate everything works:
   ```bash
   npm test              # Run all tests (config + unit + integration)
   npm run test:e2e:ship # Run e2e tests against local ship environment
   ```
4. **Follow the pipeline flow:**
   ```bash
   # Initialize development workspace from seed
   safe-rp-ctl init-wip
   
   # Build clean runtime from wip  
   safe-rp-ctl build-prep
   
   # Build self-contained deployment package
   safe-rp-ctl build-ship
   
   # Start local ship environment
   safe-rp-ctl start-ship
   ```

## Testing

The project includes comprehensive testing:

- **Configuration Validation** (`npm run test:config`): Validates nginx syntax and modular structure
- **Unit Tests** (`npm run test:unit`): Tests configuration loading and deterministic values
- **Integration Tests** (`npm run test:integration`): Tests full pipeline flow
- **End-to-End Tests** (`npm run test:e2e:ship`): Playwright tests against running environments

## Environment Configuration

Uses deterministic Type-5 configuration with environment-specific values:
- **Deterministic naming**: `nginx-rp-network-{env}`, `nginx-rp-{env}` 
- **Environment-specific ports**: ship=8083/8446, stage=8088/8447, prod=80/443
- **Self-contained deployment scripts**: `start-{env}.sh` for each target environment
