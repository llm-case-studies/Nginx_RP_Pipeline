# Nginx Reverse Proxy Deployment Pipeline

This repository contains the infrastructure-as-code for deploying and managing the Nginx reverse proxy for the PronunCo project and other associated services. It is designed to be a safe, reliable, and automated pipeline for managing critical web traffic infrastructure.

This project was intentionally separated from the main application repository (`PronunCo`) to enforce a clean separation between application code and infrastructure code.

## Project Goals

- **Automation:** To automate the entire process of testing and deploying Nginx configurations.
- **Safety:** To implement robust safety checks, including configuration validation and automated health checks, to prevent production outages.
- **Maintainability:** To use a modular, decomposed configuration structure (`conf.d`) that is easy to read and manage.
- **High-Fidelity Local Development:** To provide a local development experience that perfectly mirrors the production environment, including local SSL support via `mkcert`.

## Documentation

- **[Architecture](./docs/ARCHITECTURE.md):** A high-level overview of the pipeline's components and workflow.
- **[Requirements](./docs/REQUIREMENTS.md):** The technical requirements for running the pipeline.
- **[User Guide](./docs/USER_GUIDE.md):** Instructions for application developers who need to host their apps behind the proxy.
- **[Admin Guide](./docs/ADMIN_GUIDE.md):** Instructions for the administrator who operates the pipeline.

## Getting Started

1.  Clone this repository.
2.  Install the required software (see [Requirements](./docs/REQUIREMENTS.md)).
3.  Follow the instructions in the [Admin Guide](./docs/ADMIN_GUIDE.md) to perform your first deployment.

- Container naming: local=nginx-rp-local, stage=nginx-rp-stage, preprod=nginx-rp-pre-prod, prod=nginx-rp-prod. Override in deploy.conf if your org prefers different names.
