## “Kick-starter” guide for Gemini (or any new engineer)
Below is a single hand-off note you can paste into a chat with Gemini or drop into docs/QUICK_START_FOR_AI.md.
It explains how to pull the repo, spin up the pipeline, coach app teams, and know which artefact types are supported.

### 1 · Get the toolkit from GitHub
```bash
# 1. clone
git clone https://github.com/llm-case-studies/Nginx_RP_Pipeline.git
cd Nginx_RP_Pipeline

# 2. add helper scripts to PATH (or always call with ./scripts/…)
export PATH=$PATH:$(pwd)/scripts

# 3. install host prereqs (Debian/Ubuntu shown)
sudo apt update && sudo apt install -y docker.io mkcert jq unzip rsync

# 4. create local dev certs once
mkcert -install
```

### 2 · Smoke-test the pipeline locally

| Goal | Command | What to watch for |
| :--- | :--- | :--- |
| Blank bootstrap | `./scripts/safe-rp-ctl build-local` | • `runtime/` tree appears<br>• `rp-local` container starts ( `docker ps` )<br>• Browser hits `https://localhost:8443` without 502 |
| Overlay new zips | Drop two .zips into `/mnt/pipeline-intake` then:<br>`./scripts/safe-rp-ctl build-local --overlay-only` | Only those two apps’ folders update under `runtime/www/`; container is not restarted. |
| Promote to stage | `./scripts/safe-rp-ctl start --env stage` (on stage box) | Container `rp-stage` mounts the same runtime; health probe passes. |
| Deploy to prod | `./scripts/safe-rp-ctl deploy-prod` (on prod) | New timestamp dir in `/home/proxyuser/`, `rp-prod` re-mounts, `list-releases` shows it as current. |
| Clone prod → debug | `./scripts/safe-rp-ctl clone-prod` (dev laptop) | Local `runtime/` now mirrors live prod; you can reproduce issues. |

### 3 · Guide for application teams

#### Package layout

```
awesome-app-v2.1.zip
├── app.conf           # Nginx server block / location rules
└── dist/              # Built static assets (index.html, js, css, images…)
```

`app.conf` must not bind `listen` ports; it goes inside a global `server` from `conf/nginx.conf`.

Zip root must contain exactly one `app.conf` and a `dist/` folder.

#### How to create

| Framework | Build command | Include in zip |
| :--- | :--- | :--- |
| React (CRA / Vite) | `npm run build` | `dist/` or `build/` → rename to `dist/` before zipping |
| Angular | `ng build --configuration=production` | `dist/<app>/` → rename `dist/` |
| Vue (Vite) | `npm run build` | `dist/` |
| Static export (Next.js / Nuxt) | `next export` or `nuxt generate` | `output` folder renamed to `dist/` |
| Server-side Node, Go, etc. | Not supported here – reverse proxy expects pre-built static bundles only. | |

Naming rule: `my-app-<semver>.zip` ⇒ folder will mount at
`https://<your-domain>/<app-name>/` or per-app `server_name` in `app.conf`.

#### Where to drop

Teams copy their zips into the shared path (hard-coded in the script):

```bash
/mnt/pipeline-intake/
└── awesome-app-v2.1.zip
```

Release manager then runs `build-local` (overlay) → `stage` → `preprod` → `prod`.

### 4 · Supported package types

| Type | Supported? | Notes |
| :--- | :--- | :--- |
| Pure static SPA (React, Vue, Angular, Svelte, Astro, plain HTML) | ✅ | Produce a `dist/` folder as above. |
| Static-export Next.js / Nuxt | ✅ | Ensure no serverless functions left; only static assets. |
| SSR / API servers (Express, Fastify, Go, Django…) | ❌ | Out of scope; would require separate container flow. |
| Assets-only bundles (images / docs) | ✅ | Just zip with a dummy `app.conf` that serves files. |
| Multiple SPAs in one zip | ⚠️ Not recommended | Better to zip per-app for granular rollbacks. |

### 5 · Checklist before hitting “deploy-prod”

- `list-releases` on stage/pre-prod shows new release and health check is green.
- `describe-release <dir>` confirms only intended apps changed.
- Metrics / dashboards still clean after stage traffic replay.
- Take note of rollback target shown by `list-releases` (one line copy-paste).

If all green → `deploy-prod`, otherwise `rollback` takes one command.
