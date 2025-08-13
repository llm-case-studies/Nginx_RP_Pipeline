# Testing Improvement Proposals

Scope: Strengthen unit/integration (Bats) and end‑to‑end (Playwright) tests while minimizing churn. Focus on stability, clarity, and faster feedback.

## Overall
- **Unify environment coordinates**
  - Define `ENV`, `HTTP_PORT`, `HTTPS_PORT`, and host list once (e.g., `tests/.env`), and load in both Bats and Playwright to avoid drift.
- **Make refactor‑aware tests consistent**
  - Mirror the refactoring detection used in `tests/integration/pipeline_flow.bats` across unit tests that assert `seed` architecture.
- **Common test helpers**
  - Create `tests/helpers.bash` for Bats with: repo root cd, `is_refactor` flag, nginx syntax helpers.
- **Deterministic temp workspace**
  - Allow tests to set `WORKSPACE_ROOT` so pipeline scripts operate in a temporary workspace during tests.
- **Artifacts on failure**
  - On Bats failures, print snippets of `nginx.conf` and `conf.d/*.conf` to aid triage.

## Bats (Unit / Integration)
- **Refactor‑aware seed assertions**
  - Adjust `tests/unit/config_validation.bats` to skip or branch when `seed` is intentionally monolithic during refactoring.
  - Example:
    ```bash
    is_refactor() { [ ! -d "workspace/seed/conf.d" ] && [ -d "workspace/wip/conf.d" ]; }
    @test "seed nginx.conf uses modular conf.d structure" {
      cd "$BATS_TEST_DIRNAME/../.."
      if is_refactor; then skip "Seed is old arch during refactor"; fi
      run grep -q "include /etc/nginx/conf.d/\\*.conf" workspace/seed/nginx.conf
      [ "$status" -eq 0 ]
    }
    ```
- **Extract helpers**
  - New `tests/helpers.bash` with: `repo_root()`, `is_refactor()`, `nginx_syntax_ok(conf_path)` wrapper.
- **Stronger nginx syntax checks**
  - Encapsulate `nginx -T` call and assert no `unexpected` or `unknown directive` strings.
- **Failure diagnostics**
  - In `pipeline_flow.bats` `teardown`, dump relevant config on failure to speed diagnosis.
- **Isolation**
  - Prefer running pipeline steps against a temp `WORKSPACE_ROOT` to avoid mutating the repo during tests.

## Playwright (E2E)
- **Projects per environment**
  - In `playwright.config.ts`, define projects for `ship`, `stage`, `preprod`, `prod` with dedicated `baseURL` and resolver rules.
  - Add `retries: 2` and `workers: 1` for local Docker to reduce flake.
- **Centralize env/hosts**
  - Create `tests/e2e/fixtures/env.ts` exporting `hosts`, `ports`, and `urlFor(host, path)`; import in specs.
- **TLS assertions gating**
  - Replace port heuristics with a flag: `REQUIRE_VALID_CERT=1` to run strict cert validation; otherwise skip/soft‑check.
- **Security/header checks**
  - Assert presence/shape (regex) for `strict-transport-security`, `x-content-type-options`, `referrer-policy`, CSP if present.
- **Additional fast checks**
  - 404 and 405 responses; gzip/brotli (`content-encoding`), canonical redirects (www → apex, case normalization), cache‑control for static.
- **Traces and HAR on failure**
  - Keep `trace: 'on-first-retry'`; optionally record minimal HAR on CI failures and archive artifacts.
- **Selector robustness**
  - Prefer `getByRole`/`getByTestId` over brittle CSS; keep `body` text checks as fallback only.
- **Host resolution**
  - Keep `--host-resolver-rules` for Chromium; consider analogous mappings through context options; document limits on non‑Chromium.
- **CI commands and reporting**
  - Add script aliases to select projects by name; always publish `playwright-report/` and `test-results/` artifacts in CI.

## Suggested small edits (low risk, high value)
- `tests/unit/config_validation.bats`: make seed test refactor‑aware.
- `tests/integration/pipeline_flow.bats`: add diagnostics in `teardown()` when tests fail.
- `playwright.config.ts`: add `retries`, `workers`, and multi‑project envs.
- New `tests/e2e/fixtures/env.ts`: centralize hosts/ports.
- Specs: replace exact header values with regex presence checks; add small request‑level tests (404, redirects, compression).

## Optional enhancements
- **bats-assert/bats-support**: cleaner assertions in Bats.
- **Playwright MCP**: add IDE‑driven smoke tools for ad‑hoc checks; keep pipeline on CLI.
- **Docs**: update `docs/REMOTE_DEPLOYMENT_ARCHITECTURE_DISCUSSION.md` with `REQUIRE_VALID_CERT` flag and project naming.

## Actionable checklist
- [ ] Create `tests/helpers.bash` and source it in Bats suites
- [ ] Make `tests/unit/config_validation.bats` refactor‑aware
- [ ] Add diagnostics to `tests/integration/pipeline_flow.bats` teardown
- [ ] Add `retries: 2`, `workers: 1`, and env projects to `playwright.config.ts`
- [ ] Create `tests/e2e/fixtures/env.ts`; refactor specs to use it
- [ ] Add small request‑level tests (404, redirects, compression)
- [ ] Configure CI to archive Playwright artifacts and show report

## Test grouping for execution contexts

Two practical groups:

- **Dev‑local (project root only)**
  - Requires repo workspace layout (seed/wip/prep/ship) and local Docker
  - Includes: `tests/unit/*`, `tests/integration/pipeline_flow.bats`, `playwright` against local ship
  - Command: `npm run test:dev-local`

- **Env‑agnostic (any environment: wip/prep/ship/stage/preprod/prod)**
  - Pure HTTP/TLS behavior via Playwright against a provided `BASE_URL`/ports
  - Run in CI or on remote envs without touching repo workspaces
  - Commands:
    - `npm run test:env-any` (uses `playwright.config.ts` defaults)
    - `npm run test:env-any:custom` with env vars, e.g.:
      ```bash
      BASE_URL=https://stage.example.com REQUIRE_VALID_CERT=1 npm run test:env-any:custom
      ```

---

## MCP integrations to add (code quality, testing, refactoring)

- Code quality
  - Semgrep MCP: static/security rules; JSON findings; optional autofix.
  - ESLint MCP: lint/--fix for JS/TS; SARIF/JSON output.
  - Prettier MCP: format files or diffs on demand.
  - ShellCheck MCP: shell lint with fix suggestions.
  - Hadolint MCP: Dockerfile lint (pinning, best practices).
  - yamllint + markdownlint MCP: config/docs hygiene.
  - Trivy MCP: filesystem/image scan for CVEs (baseline only).

- Testing
  - Playwright MCP: targeted navigate/assert/screenshot for fast smoke.
  - HTTP MCP: GET/HEAD, redirects, headers, gzip, TLS info; lightweight gates.
  - Bats MCP (wrapper): run a single Bats test and return parsed result.
  - k6 MCP (optional): small perf smoke for critical endpoints.

- Refactoring
  - Codemod MCP (jscodeshift): structural edits in JS/TS with preview.
  - TS‑morph MCP: rename/extract/move with type safety.
  - Python libcst MCP: safe Python codemods (imports, APIs).
  - OpenRewrite MCP: Java/YAML recipe‑driven refactors.
  - Serena MCP: keep; expose common refactor actions as tools.

- Nginx/domain‑specific
  - Nginx Validate MCP: run nginx -t/-T, parse errors, suggest fixes.
  - Config Drift MCP: diff `conf.d` across stages, highlight drift.

- Cross‑cutting automation
  - Pre‑commit MCP: run hooks (eslint, shellcheck, prettier) on changed files and return fixable patch.
  - Conventional Commits MCP: lint/compose commit messages.
  - Changelog MCP: generate/update CHANGELOG from commits.

---

## Spin‑off project: Smart Monitor (tiny LLM + HTTP MCP)

Goal: Continuous, adaptive smoke checks across environments (wip/prep/ship/stage/preprod/prod) with minimal infra.

- Architecture
  - HTTP MCP server: runs near targets; tools: request/assert/headers/tlsInfo/download.
  - Agent: small process using a tiny LLM (e.g., 7–8B instruct or GPT‑4o‑mini) to select checks, call MCP, and evaluate.
  - Spec: YAML checks + budgets; outputs: JSON results, artifacts, alerts.
  - Storage: per‑env results under `/var/lib/workflow/monitoring/` and optional commit to Git ledger/index.

- Check spec (example)
  ```yaml
  checks:
    - id: redirect_https
      url: http://cutietraders.com/
      expect:
        status: [301,302,308]
        headers:
          location: contains:https://cutietraders.com
    - id: security_headers
      url: https://iLegalFlow.com/
      expect:
        status: 200
        headers:
          strict-transport-security: matches:^max-age=\d+
          x-content-type-options: equals:nosniff
    - id: tls_chain_valid
      url: https://iMediFlow.com/
      tls: { verify: true }
  ```

- Guardrails
  - Host allow‑list; methods GET/HEAD by default.
  - Timeouts, rate limits, response size caps; redact sensitive headers.
  - Deterministic loop: plan → probe → evaluate → report (with one retry max).

- MVP plan (1–2 days)
  - Implement HTTP MCP with allow‑list and caps.
  - Define ~12 checks for ship/stage (redirects, headers, gzip, TLS).
  - Write agent harness (Python) with a tiny LLM; JSON reports + Slack/email on failure.
  - Systemd timer per env; artifacts archived under monitoring path.

- Stretch
  - Trend baselines (latency windows), canary scoring, and auto‑quarantine recommendations.

