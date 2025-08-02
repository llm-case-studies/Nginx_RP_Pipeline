### Subject: Deploy in Minutes, Not Hours: A New Self-Service Pipeline for Your Apps

Hi Team,

We've built a new self-service deployment pipeline to eliminate the friction of our old manual process. For you, this means you can now deploy your applications faster, more often, and with greater confidence.

This new system is designed to give you more power and to remove common bottlenecks.

#### How You Benefit

*   **Ship Faster & More Often:** Deployments are now self-service. Once your app is ready, the pipeline can deploy it in minutes, not hours. No more filing tickets or waiting in a queue.
*   **Deploy with Confidence:** Every change is automatically validated before it goes live. The system checks for configuration errors and runs health checks, creating a powerful safety net that protects all applications from accidental outages.
*   **Own Your Configuration:** The Nginx server block for your application is now part of your artifact. You can add custom headers, redirects, or location blocks yourself. No more filing a ticket and waiting for the infrastructure team to make a change.
*   **Eliminate Surprises with True Local SSL:** The pipeline is designed to use `mkcert`, allowing you to run a full, production-identical HTTPS environment on your local machine. You'll get the green padlock locally, which means no more deployment-day surprises related to CORS, mixed-content, or secure cookies.

#### How to Prepare Your Application

The process is straightforward. You provide a single **Application Artifact Bundle** (`.zip` file). This is the contract between your app and the pipeline.

The bundle must be named `<app-name>-<version>.zip` and contain two things:

1.  **`dist/` directory:** All your application's static, compiled assets (`index.html`, JS, CSS, etc.).
2.  **`app.conf` file:** A simple Nginx `server` block for your application.

**Example `app.conf` for a React/Vue/Svelte App:**
```nginx
server {
    # This line is critical - it lets the pipeline manage ports
    include /etc/nginx/ports.conf;

    server_name my-amazing-app.pronunco.com;

    location / {
        root /var/www/my-amazing-app/;
        index index.html;
        # Essential for single-page apps with client-side routing
        try_files $uri $uri/ /index.html;
    }
}
```
*(For more examples, including backend proxies, please see the full `USER_GUIDE.md`.)*

#### How to Maximize the Benefits

To get the most out of the new pipeline, consider these design patterns:

*   **Create a `/healthz` Endpoint:** Add a simple `/healthz` or `/status` endpoint to your application that returns a `200 OK`. The pipeline's automated health check will hit this endpoint after every deployment. If it doesn't return a `200 OK`, the deployment is **automatically rolled back**. This is a powerful safety net that ensures a broken build can never take down your service.
*   **Automate Your Artifact Creation:** The ideal workflow is for your own CI/CD process (e.g., GitHub Actions, Jenkins) to automatically build and deliver the `.zip` artifact. This creates a true end-to-end, "git push to deploy" experience.
*   **Embrace Statelessness:** The pipeline is designed for modern, stateless applications. It treats your `dist/` directory as immutable. If your application requires persistence, it should use a dedicated database or object store.

We're confident this new process will significantly improve our development and deployment cycles. Please review the `docs/USER_GUIDE.md` for complete details.

Thanks,
The Pipeline Team