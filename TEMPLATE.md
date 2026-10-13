# Hermes Agent v0.21 Always-On (Telegram, Discord, Slack): Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **Hermes Agent v0.21 Always-On (Telegram, Discord, Slack)** (LISTINGS.md name with version label "v0.21" inserted after the software name: pinned release `v0.21.7` is a 0.x release, so major.minor, and Hermes tags with a `v`) |
| Description | Self-improving AI agent running 24/7 with web chat UI, memory and browser (73 chars; was "Self-improving AI agent running 24/7 with persistent memory and a browser." before the WebUI was added) |
| Category | AI/ML |
| Tags | hermes-agent, ai-agent, nous-research, telegram, discord, slack, llm, automation, web-ui, chat-ui |

The description is delivered as written:
- **24/7**: the gateway (`gateway run`) runs as the container's main process; the dashboard and the WebUI run in restart loops next to it; Railway's `ON_FAILURE` policy restarts the container.
- **Web chat UI**: Hermes WebUI (community project, MIT) runs inside the Hermes service and is published through the small `Hermes WebUI` proxy service, with a generated password.
- **Memory**: `HERMES_HOME=/opt/data` (memories, skills, sessions `state.db`, cron jobs, pairing approvals, config, WebUI state) lives on a Railway volume.
- **Browser**: the official image ships a pinned full Chromium and the `agent-browser` driver, so the browser tools work without an extra service (see "Browser design decision").

## Base market template

- **Base: `hermes-railway-template`** ("Hermes Agent by Nous Research", the market leader by recent deploys when this template was first built). Kept the core idea: run the **official `nousresearch/hermes-agent` image** as an always-on gateway with a persistent volume and configuration through Railway variables. Its repo (`lovexbytes/hermes-railway-template`) has **no license**, so nothing was copied. It builds a derived image from the floating `latest` tag, rewrites `/data/.hermes/.env` on every boot, has no dashboard, no healthcheck, and requires OpenRouter + Telegram + a Telegram allowlist.
- `hermes-agent-ai` / `hermes-agent-nous-research` (praveen-ks-2001): build Hermes from source and wrap it with a ~4,400-line custom Flask admin app that reverse-proxies the native dashboard; browser tools disabled. No license, nothing copied. Idea taken: the native dashboard is what users want; we get it from upstream directly.
- Round 3 review (WebUI), all read for ideas only, nothing copied:
  - `hermes-agent-all-in-one` (protemplate, 154 projects / 89 active): Hermes WebUI + agent in **one container** sharing `/data`, a custom Starlette wrapper with a web terminal, SearXNG sidecar; builds Hermes and WebUI from git, gateway **off by default** (`START_GATEWAY=false`), no official dashboard. Repo has no license. Confirms the architecture: WebUI must share the agent's home directory, so it lives in the agent's service.
  - `hermes-agent-with-official-dashboard` (mazshakibaii, 193 / 115): dashboard behind a custom cookie proxy, `git pull` on every boot (`AUTO_UPDATE=true`), volume optional, empty required password. No license.
  - `hermes-agent-official` (232 / 129): official image `:latest`, `GATEWAY_ALLOW_ALL_USERS=true` and the API server enabled by default (anyone who finds the bot can use the owner's LLM key). Not followed.
- No README text was reused.

## Pinned versions

| Service | Image | Tag | Release date | Checked |
|---|---|---|---|---|
| Hermes | `nousresearch/hermes-agent` (Docker Hub, official) | `rc.15-v0.21.7@sha256:444b4259…fad8b` = release **v0.21.7** | 2026-10-11 (GitHub release 2026-10-12) | 2026-10-13 |
| Hermes (WebUI layer) | `ghcr.io/nesquena/hermes-webui` (official image of the community project) | `0.52.113@sha256:48ba6ee4…a746e` = latest **stable** release v0.52.113 | 2026-08-14 | 2026-10-13 |
| Hermes WebUI (proxy) | `caddy` (Docker Official Image) | `2.11.7-alpine@sha256:d8542f48…5f75f` | 2026-10-03 | 2026-10-13 |

Why the Hermes tag looks like a release candidate: since v0.21.7 upstream publishes Docker images through a staged release flow. Each attempt gets an immutable `rc.N-vX.Y.Z` tag; when an attempt becomes the release, `:stable`/`:latest` are moved onto it and no plain `v0.21.7` tag is created. The annotated git tag `v0.21.7` names `claimTag: rc.15-v0.21.7` and `dockerManifestDigest: sha256:444b42594e7f…`, which is the digest pinned here (and the digest `:stable` pointed to on 2026-10-13).

WebUI version choice: `0.52.113` is the newest release on the WebUI's stable channel. Its `:latest` and `:experimental` tags currently resolve to the same digest (daily experimental build 0.52.468), so floating tags are not used. See "Open questions" for the known compatibility gap between WebUI 0.52.113 and Hermes v0.21.x.

Upgrade: edit both `FROM` lines in `services/hermes/Dockerfile` (upstream treats WebUI and agent as a release pair), redeploy, then run `hermes config migrate` once via `railway ssh` if the release notes ask for it. Never run `hermes update` inside the container (the install tree is immutable in the official image).

## Architecture

```
 Telegram / Discord / Slack  ◄── outbound bot connections (no inbound ports needed)
                 ▲
                 │
   ┌─────────────┴───────────────────────────────────────────────┐
   │ Hermes (official image v0.21.7 + WebUI source, repo build)   │
   │  railway-start.sh (Railway's init is PID 1, not s6)         │
   │   ├─ gateway run   main process: agent, cron, kanban        │
   │   ├─ dashboard     restart loop, 0.0.0.0:9119  ◄── public domain (unchanged)
   │   ├─ Hermes WebUI  restart loop, [::]:8787 (private only)    │
   │   └─ on demand: agent-browser + bundled headless Chromium    │
   │  volume /opt/data = HERMES_HOME (state.db, memories, skills, │
   │                     config, webui/ sessions + login state)  │
   └─────────────▲───────────────────────────────────────────────┘
                 │ http://hermes.railway.internal:8787 (private network)
   ┌─────────────┴──────────────────────────┐
   │ Hermes WebUI (caddy:2.11.7-alpine)     │ ◄── public domain, :8080
   │  reverse proxy only, /proxy-health     │
   └────────────────────────────────────────┘
```

### How Hermes WebUI talks to Hermes (and why it runs inside the Hermes service)

Checked against `docker-compose.yml`, `docker-compose.two-container.yml`, `docker-compose.three-container.yml` and `docs/docker.md` of nesquena/hermes-webui:

- The WebUI **imports the agent's Python code and runs turns in-process** (`HERMES_WEBUI_AGENT_DIR`, `run_agent.py`). It reads and writes the **shared Hermes home directory directly**: `config.yaml`, `.env`, `state.db` (gateway sessions in the sidebar, polled every 5 s), skills, memory, cron `jobs.json`, and keeps its own state in `HERMES_HOME/webui`.
- Upstream's multi-container layouts therefore mount the **same `hermes-home` volume** into both containers, plus the agent's source tree. The gateway HTTP API (port 8642, needs `API_SERVER_KEY`) is only used for health/cron-tick status and an optional gateway chat backend; it does not replace the shared directory.
- Upstream also notes (#681) that in split setups the WebUI's tools run in the WebUI container, which lacks the agent image's tools (Chromium, Node, git).

A Railway volume belongs to exactly one service, so a separate WebUI service cannot share `/opt/data`. The WebUI therefore runs **inside the Hermes service** on the agent's own venv (`/opt/hermes/.venv`). The WebUI's only extra dependencies are cryptography (already in the venv) and PyYAML (Hermes itself uses ruamel.yaml); because the venv is sealed, PyYAML 6.0.3 is installed at build time into `/opt/hermes-webui-deps` with the WebUI image's `uv` and put on the WebUI process's `PYTHONPATH` only. Result: one writer set, one config, tools and Chromium available to WebUI chats, Telegram/Discord/Slack sessions visible in the WebUI sidebar. The API server stays off.

### Routing: why a proxy service and not a second domain

The Hermes service's public domain already targets the dashboard (port 9119) and must not change for the existing deployment. Railway documents "target ports" for several domains per service, but `_tools/to_serialized.py` emits one `serviceDomains` entry per service, no market template ships two domains on one service, and `${{RAILWAY_PUBLIC_DOMAIN}}` (used by `HERMES_DASHBOARD_PUBLIC_URL`) would become ambiguous. So the WebUI gets its own tiny service: Caddy with a public domain, forwarding to `${{Hermes.RAILWAY_PRIVATE_DOMAIN}}:8787`. This uses only features the template already relies on (private networking, one domain per service) and needs no serializer change. Caddy passes `Host` through unchanged (the WebUI's CSRF check compares `Origin` with `Host`), flushes server-sent events immediately, and answers its own `/proxy-health`, so it turns healthy while Hermes is still building.

## Services

### Hermes

| Setting | Value |
|---|---|
| Source | `services/hermes`: official image `nousresearch/hermes-agent:rc.15-v0.21.7@sha256:444b…` + WebUI source copied from `ghcr.io/nesquena/hermes-webui:0.52.113@sha256:48ba…` (`/apptoo` → `/opt/hermes-webui`, root-owned, read-only for the runtime user) + PyYAML in `/opt/hermes-webui-deps` (build stage `webui-deps`) + `railway-start.sh` as ENTRYPOINT, CMD `gateway run` |
| Healthcheck | `/api/health` on 9119 (upstream's unauthenticated dashboard liveness probe), timeout 300 s |
| Public domain | yes, target port **9119** (dashboard), unchanged |
| Private ports | 8787 (WebUI, reached by the `Hermes WebUI` service) |
| TCP proxy | none |
| Volume | `/opt/data` (official `HERMES_HOME`), unchanged |
| Restart policy | ON_FAILURE, 10 retries |
| Replicas | 1 (must stay 1: upstream forbids two gateways on one data directory) |

Why the wrapper: Railway runs containers under its own init (`podman-init` is PID 1), so the image's dispatcher takes its non-PID-1 path and skips s6-overlay; no supervised services start. `railway-start.sh` repeats upstream's fallback (stage2 bootstrap, then `main-wrapper.sh`, which drops to the `hermes` user) and runs the dashboard and the WebUI as `hermes` in restart loops next to the gateway. The WebUI is started only when `HERMES_WEBUI` is on **and** `HERMES_WEBUI_PASSWORD` is non-empty (upstream WebUI would otherwise serve without a login and only print a warning). `HERMES_WEBUI_PASSWORD` is unset before the dashboard and gateway start, so it is not in their (or their tools') environment.

Variables (all have descriptions in `template.json`):

| Variable | Default | Notes |
|---|---|---|
| `OPENROUTER_API_KEY` | (required, user input) | The only required input. Shared by gateway, dashboard and WebUI chats. |
| `TELEGRAM_BOT_TOKEN` | empty | Recommended first platform. |
| `TELEGRAM_ALLOWED_USERS` | empty | Empty = deny-all + DM pairing (approve in dashboard → Pairing). |
| `DISCORD_BOT_TOKEN`, `DISCORD_ALLOWED_USERS` | empty | Optional platform. |
| `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`, `SLACK_ALLOWED_USERS` | empty | Optional platform (Socket Mode needs both tokens). |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` | empty | Optional direct provider keys. |
| `HERMES_INFERENCE_MODEL` | empty | Optional hard override of the model. |
| `HERMES_DASHBOARD` | `1` | Runs the official dashboard. |
| `HERMES_DASHBOARD_HOST` / `_PORT` | `0.0.0.0` / `9119` | Upstream defaults, made explicit. |
| `HERMES_DASHBOARD_PUBLIC_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Exact host for the Host/Origin guard and OAuth callbacks. |
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` | `admin` | Dashboard login. |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | `${{secret(32)}}` | Generated. |
| `HERMES_DASHBOARD_BASIC_AUTH_SECRET` | `${{secret(64)}}` | Stable session-signing key. |
| `HERMES_DASHBOARD_OAUTH_CLIENT_ID` | empty | Optional upgrade to Nous Portal OAuth. |
| **`HERMES_WEBUI`** (new) | `1` | Runs Hermes WebUI. Unset (existing deploys) = off. |
| **`HERMES_WEBUI_PASSWORD`** (new) | `${{secret(32)}}` | WebUI login; the WebUI does not start without it. PBKDF2-hashed in memory by the WebUI; sessions are signed with a key the WebUI keeps in `/opt/data/webui` (30-day sessions survive restarts). |
| **`HERMES_WEBUI_HOST`** (new) | `::` | Dual-stack bind (threaded stdlib server, so `::` also accepts IPv4); needed for the private network. |
| **`HERMES_WEBUI_PORT`** (new) | `8787` | Upstream default; referenced by the proxy service. |
| **`HERMES_WEBUI_SECURE`** (new) | `1` | `Secure` flag on WebUI session cookies (HTTPS only). |
| `AGENT_BROWSER_ARGS` | `--no-sandbox,--disable-dev-shm-usage` | Container-safe Chromium flags. |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `30` | Graceful stop for in-flight turns and SQLite checkpoints. |
| `PORT` | `9119` | Railway healthcheck/public port = dashboard. |

Set by `railway-start.sh`, not variables: `HERMES_WEBUI_AGENT_DIR=/opt/hermes`, `HERMES_WEBUI_PYTHON=/opt/hermes/.venv/bin/python`, `PYTHONPATH=/opt/hermes-webui-deps` (WebUI process only), `HERMES_WEBUI_STATE_DIR=/opt/data/webui`, `HOME=/opt/data` (so the default WebUI workspace is `/opt/data/workspace`, on the volume).

Not set on purpose: `API_SERVER_*` (the OpenAI-compatible API server stays off; the WebUI does not need it in the same container), `GATEWAY_ALLOW_ALL_USERS`, `HERMES_WEBUI_TRUST_FORWARDED_FOR` / `HERMES_WEBUI_TRUSTED_PROXY_CIDRS` (Railway's edge and proxy IPs are not documented; without them the WebUI keys its login rate limit on the proxy address, see Open questions), `HERMES_WEBUI_ONBOARDING_OPEN` (would allow unauthenticated onboarding), `HERMES_WEBUI_TRUSTED_AUTH_HEADER` (header-based auth would let anyone who can reach port 8787 set the header).

### Hermes WebUI (new)

| Setting | Value |
|---|---|
| Source | `services/webui-proxy`: `caddy:2.11.7-alpine@sha256:d854…` + `Caddyfile` (validated at build) |
| Healthcheck | `/proxy-health` (answered by Caddy), timeout 120 s |
| Public domain | yes, target port **8080** |
| Volume | none (stateless) |
| Restart policy | ON_FAILURE, 10 retries |
| Variables | `HERMES_WEBUI_UPSTREAM=${{Hermes.RAILWAY_PRIVATE_DOMAIN}}:${{Hermes.HERMES_WEBUI_PORT}}`, `PORT=8080` |

When the WebUI is down or disabled, the proxy answers 503 with a plain-text hint instead of a bare 502.

### Browser design decision

Unchanged from the first release: the **packaged Chromium inside the official image** is used, no Browserless sidecar (Hermes opens two CDP sessions per browser and Browserless v2 starts a new browser per WebSocket, so console evaluation would hit an empty page). Cloud providers (`BROWSERBASE_API_KEY`, `BROWSER_USE_API_KEY`) remain available. WebUI chats run in the Hermes container and therefore get the same browser.

## First login

1. **Dashboard**: open the `Hermes` service's public URL, sign in as `admin` with `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` (Variables tab). Check the gateway status and pick the default model under Config / Models (the stock default is an expensive Opus-class model through OpenRouter).
2. **WebUI**: open the `Hermes WebUI` service's public URL (works on a phone; it can be added to the home screen), enter `HERMES_WEBUI_PASSWORD` from the **Hermes** service's Variables tab. Start a chat; the model and provider come from the same Hermes config. Telegram/Discord/Slack conversations appear in the sidebar.
3. DM your bot. Without an allowlist you receive a pairing code; approve it on the dashboard's **Pairing** page.
4. Optional: Channels page for more platforms, API Keys for more providers, Cron for scheduled jobs (also visible in the WebUI's Tasks panel).

Existing deployments (created before the WebUI was added) keep working unchanged after updating: the WebUI stays off until `HERMES_WEBUI=1` and `HERMES_WEBUI_PASSWORD` are added to the Hermes service and a `Hermes WebUI` proxy service (or a second domain on port 8787) is added.

## Improvements over market templates

1. **Official images, pinned by tag and digest** (Hermes v0.21.7, WebUI v0.52.113, Caddy 2.11.7) instead of `latest`, `git pull` on boot, or from-source builds.
2. **Gateway, official dashboard and Hermes WebUI together**, sharing one `HERMES_HOME`: market templates offer either the dashboard or the WebUI, and the WebUI bundle ships with the gateway off.
3. **WebUI fails closed**: it is never started without a password; the password is generated with `secret(32)`; session cookies are `Secure`; the password is kept out of the gateway's environment.
4. **Healthchecks** on `/api/health` (Hermes) and `/proxy-health` (proxy), the latter independent of Hermes build time.
5. **Browser tools work** in gateway, dashboard and WebUI chats (bundled Chromium + container-safe flags).
6. **Secure-by-default access**: deny-all + DM pairing; no allow-all switch; API server off.
7. **One required input** (OpenRouter key).
8. **Graceful redeploys** (`RAILWAY_DEPLOYMENT_DRAINING_SECONDS=30`) to protect `state.db`.

## Resource estimate

Railway prices: RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month. Estimates, not measurements (the WebUI process could not be measured locally for this revision).

| Service | Idle RAM / CPU | Typical RAM / CPU | Notes |
|---|---|---|---|
| Hermes (gateway + dashboard + WebUI) | 0.95 GB / 0.05 vCPU | 1.7 GB avg, 3 GB peaks / 0.25 vCPU | WebUI adds ~0.25 GB (Python + in-process agent). Peaks while Chromium runs or several chats stream at once |
| Hermes WebUI (Caddy) | 0.02 GB / ~0 vCPU | 0.04 GB / 0.01 vCPU | Reverse proxy only |
| Volume `/opt/data` | 0.5 GB | 2-3 GB | Sessions, memories, skills, WebUI state and workspace |

Estimated monthly cost: **idle ≈ $11**, **typical ≈ $22-24** (1.74 GB × $10 + 0.26 vCPU × $20 + 2 GB × $0.15). LLM usage is billed by your provider, not Railway.

Minimum plan: **Hobby**. Trial (1 GB per service) cannot hold gateway + dashboard + WebUI. Pro only for more than the Hobby per-service limits.

## Verification checklist

- [ ] Hermes deploy logs show `[stage2]` lines, the gateway banner, the dashboard start and `Hermes Web UI listening on http://:::8787`; no `[railway-start] Hermes WebUI not started` line; no `missing modules` warning from the WebUI.
- [ ] `GET https://{hermes-domain}/api/health` returns 200; `/api/status` reports `auth_required: true`.
- [ ] `GET https://{webui-domain}/proxy-health` returns 200 (Caddy) even before Hermes is up; then `GET /health` returns 200 (WebUI, public).
- [ ] WebUI rejects anonymous access: `GET /` → 302 to `login`, `GET /api/sessions` → 401 `Authentication required`, `GET /api/auth/status` shows auth enabled.
- [ ] WebUI login with `HERMES_WEBUI_PASSWORD` works; the `Set-Cookie` has `HttpOnly; Secure; SameSite=Lax`; the session survives a redeploy.
- [ ] WebUI chat: send "open https://example.com and tell me the page title"; the reply streams token by token (SSE through Caddy and Railway's edge) and says "Example Domain".
- [ ] A Telegram conversation shows up in the WebUI sidebar within a few seconds (shared `state.db`).
- [ ] Persistence: create a memory in the WebUI, ask about it on Telegram; redeploy and ask again.
- [ ] Kill test: `railway ssh` → `pkill -f hermes-webui/server.py`; the WebUI is back within ~10 s and the container stays up.
- [ ] Disable test: set `HERMES_WEBUI=0`, redeploy; the proxy returns its 503 hint and the dashboard still works.

## Open questions

- **WebUI/agent version gap (highest risk).** WebUI v0.52.113 (2026-08-14) predates Hermes' September 2026 module split. Hermes v0.21.7 no longer has the old-path pointers in `tools/approval.py` (`set_current_session_key`/`reset_current_session_key` moved) and `hermes_cli/kanban_db.py`. WebUI wraps these imports in `except`, so chat should still work, but upstream's changelog lists silent degradations that were fixed only in unreleased/experimental builds (#7574 and the `set_auto_title` fix): MCP tools missing from WebUI turns, per-turn approval session key not bound (racy under concurrent WebUI chats), kanban bridge errors, WebUI titles not written to `state.db`. The approval names WebUI imports as a group (`submit_pending`, `is_approved`, `_pending`, …) still exist in v0.21.7, so the unsafe `is_approved = True` fallback is not triggered. Not verified at runtime. Option: pin the current experimental build (`0.52.468`, which `:latest` also points to) once upstream promotes a stable release containing #7574.
- Railway's edge and the proxy are not loopback, so the WebUI's login rate limit (5 attempts per 60 s) is keyed on the proxy's address: brute force is throttled for everyone together, but an attacker who keeps failing logins can block new logins (existing 30-day sessions keep working).
- Whether Railway allows Chromium's user-namespace sandbox could not be verified (template forces `--no-sandbox`).
- Upstream labels the dashboard's username/password provider "trusted network only" and recommends Nous Portal OAuth for internet-facing dashboards.
- **Not built or run locally for this revision** (host disk full, Docker daemon unresponsive; coordinator stopped Docker work). Unverified until the Railway deploy test: the `webui-deps` stage (`uv pip install --target` against the sealed venv's interpreter), the `caddy validate` build step, the WebUI importing the v0.21.7 agent, `::` binding, SSE through Caddy and Railway's edge, and the 401/302 behaviour (taken from `api/auth.py` of v0.52.113: everything except `/login`, `/health`, static assets, manifests, `/share` links and the auth endpoints requires a valid signed session cookie once `HERMES_WEBUI_PASSWORD` is set).
- Without `HERMES_API_URL` the WebUI judges gateway health from local state files in `/opt/data` (same container, same PID namespace). Its gateway status pill may still read "not configured"; scheduled cron jobs are ticked by the running gateway either way. Not verified.
- The WebUI includes an authenticated web terminal (shell as the `hermes` user); anyone with the WebUI password has the same power as the agent's own terminal tool.

## Deploy test findings (2026-10-11)

After the PID-1 wrapper fix the dashboard listened on 9119, but the healthcheck still failed: Railway probes the port in `PORT`, which was unset. Fix: `PORT=9119`.

## Round 3 change log (2026-10-13)

- Hermes `v0.21.6` → `v0.21.7` (attempt tag + digest, see Pinned versions). Upstream docker scripts used by `railway-start.sh` (`entrypoint-dispatch.sh`, `main-wrapper.sh`, `stage2-hook.sh`, `s6-rc.d/dashboard/run`) are byte-identical between the two tags.
- Added Hermes WebUI inside the Hermes service and the `Hermes WebUI` proxy service. Only additions: no variable, service name or volume path was renamed or removed.
- Local Docker build/run verification of this revision could not be performed (host disk full, Docker daemon unresponsive); the Railway deploy test is the first runtime check.
