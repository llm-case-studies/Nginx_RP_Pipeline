# Pipeline Administrator's Guide

This guide provides instructions for the administrator responsible for operating the Nginx Reverse Proxy Pipeline.

## 1. Initial Setup

1.  Clone this repository to your local machine.
2.  Ensure all dependencies listed in `docs/REQUIREMENTS.md` are installed.
3.  For local development, follow the `mkcert` instructions in `REQUIREMENTS.md` to set up a local Certificate Authority.

## 2. Core Workflows

### 2.1. Deploying or Updating an Application

This is the most common workflow.

1.  **Receive Artifact:** Obtain the Application Artifact Bundle (`.zip` file) from the application development team.
2.  **Place Artifact:** Place the bundle in the designated `intake/` directory within this project.
3.  **Update Manifest:** Add or update the application's entry in the `sites-manifest.json` file. Ensure the `name` property matches the artifact's base name.
4.  **Deploy:** Run the deployment command:
    ```bash
    ./proxy-container.sh deploy
    ```
    The script will automatically find the correct artifact, validate the configuration, deploy it, and run health checks.
5.  **Test:** After deployment, run the full test suite to ensure all sites are healthy:
    ```bash
    ./proxy-container.sh test
    ```

### 2.2. Rolling Back a Failed Deployment

If a deployment introduces issues, you can immediately roll back to the last known-good configuration.

1.  **Run Rollback Command:**
    ```bash
    ./proxy-container.sh rollback
    ```
    The script will restore the previous configuration from the `backup/` directory and reload Nginx.

## 3. Command Reference

-   `./proxy-container.sh build`: Builds the custom Nginx Docker image.
-   `./proxy-container.sh deploy`: Deploys all applications listed in the manifest.
-   `./proxy-container.sh test`: Runs health checks against all sites in the manifest.
-   `./proxy-container.sh rollback`: Restores the previous known-good configuration.
-   `./proxy-container.sh logs`: Tails the logs of the running Nginx container.
-   `./proxy-container.sh status`: Shows the status of the Nginx container.
-   `./proxy-container.sh shell`: Opens a shell inside the running Nginx container for debugging.