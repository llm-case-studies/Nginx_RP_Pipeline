# Application Developer's Guide

This guide explains how to prepare your application to be hosted by the Nginx Reverse Proxy Pipeline.

## 1. The Developer Contract

To have your application deployed, you must provide a single, versioned `.zip` file known as the **Application Artifact Bundle**. This bundle is the contract between your application and the deployment pipeline.

The bundle must be named `<app-name>-<version>.zip` (e.g., `pronunco-ui-v1.2.0.zip`).

It must contain the following two items in its root:

1.  **`dist/` directory:** This folder must contain all the static, compiled assets required to run your application (e.g., `index.html`, CSS, JavaScript files).
2.  **`app.conf` file:** This is your Nginx `server` block configuration.

## 2. Creating Your `app.conf` File

This is the most critical part. You must provide a valid Nginx `server` block.

**Key Requirement:** Do **NOT** hardcode `listen` ports. Your configuration must use an `include` directive to inherit the port configuration from the pipeline environment.

### Example for a Static Site (e.g., a React/Vue/Svelte UI)

```nginx
# app.conf for a static Single-Page Application

server {
    # Inherit port settings from the environment
    include /etc/nginx/ports.conf;

    # Set your application's domain name
    server_name my-app.pronunco.com;

    # SSL settings will be inherited globally or can be specified here if needed

    location / {
        root /var/www/my-app/; # The pipeline will place your dist folder here
        index index.html;
        # This line is crucial for client-side routing in SPAs
        try_files $uri $uri/ /index.html;
    }

    # Add any other custom location blocks you may need
}
```

### Example for a Proxied Application (e.g., a Node.js API)

```nginx
# app.conf for a backend API

server {
    # Inherit port settings from the environment
    include /etc/nginx/ports.conf;

    # Set your application's domain name
    server_name api.my-app.com;

    location / {
        # The pipeline will configure the proxy_pass address
        proxy_pass http://my-api-container:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 3. The Deployment Process

1.  Create your Application Artifact Bundle (`.zip` file).
2.  Deliver this file to the Pipeline Administrator or place it in the designated `intake/` directory.
3.  The pipeline will handle the rest.