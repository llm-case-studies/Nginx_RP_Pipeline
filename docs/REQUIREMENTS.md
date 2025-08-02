# Pipeline Requirements

This document lists the software dependencies required to operate and develop for the Nginx Reverse Proxy Pipeline.

## 1. Runtime Requirements (Production Server)

The following software must be installed on the target server where the proxy will run.

-   **Docker:** The pipeline uses Docker to run the Nginx container. (Version 20.10 or later recommended).
-   **Git:** Used for pulling configuration updates.

## 2. Local Development Requirements (Administrator's Machine)

To run the pipeline locally for development and testing, the following software is required.

-   **Docker:** To run the Nginx container locally.
-   **Git:** For version control.
-   **mkcert:** For creating locally-trusted SSL certificates. This is essential for a high-fidelity local HTTPS environment.

### `mkcert` Setup Instructions

`mkcert` is a simple tool for making locally-trusted development certificates. It requires no configuration.

1.  **Install `mkcert`:** Follow the official installation instructions for your operating system: [https://github.com/FiloSottile/mkcert#installation](https://github.com/FiloSottile/mkcert#installation)

2.  **Create a Local Certificate Authority:** Run the following command once. This will create your own private CA and, crucially, register it with your system's trust stores (including your browsers).
    ```bash
    mkcert -install
    ```

3.  **Generate Certificates:** Navigate to the `certs/` directory in this project and generate certificates for your local development domains.
    ```bash
    mkcert app.pronunco.local api.pronunco.local localhost
    ```
    This will create the `.pem` certificate files that your local Nginx instance can use.