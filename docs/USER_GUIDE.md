# Application Developer's Guide

This guide explains how to prepare your application to be hosted by the Nginx Reverse Proxy Pipeline using the new **seed → wip → prep → ship** architecture.

## 1. The Enhanced Developer Contract

To have your application deployed, you must provide a single, versioned `.zip` file known as the **Enhanced Application Artifact Bundle**. This bundle supports both static sites and backend services.

**Bundle Structure:**
```
<app-name>-<version>.zip
├── dist/                    # Static assets (required)
├── nginx/                   # Nginx configuration (required)  
│   └── <app-name>.conf
└── containers/              # Backend services (optional)
    └── <app-name>.yml
```

**Examples:**
- `pronunco-ui-v1.2.0.zip` (static site)
- `pronunco-api-v2.1.0.zip` (API service with backend)

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