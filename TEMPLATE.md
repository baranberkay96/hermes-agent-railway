# Hermes Agent v0.21 Always-On (Telegram, Discord, Slack): Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **Hermes Agent v0.21 Always-On (Telegram, Discord, Slack)** (LISTINGS.md name with version label "v0.21" inserted after the software name: pinned release `v0.21.6` is a 0.x release, so major.minor, and Hermes tags with a `v`) |
| Description | Self-improving AI agent running 24/7 with persistent memory and a headless browser. (83 chars, unchanged) |
| Category | AI/ML |
| Tags | hermes-agent, ai-agent, nous-research, telegram, discord, slack, llm, automation |

The description is delivered as written:
- **24/7**: the official image runs `gateway run` under s6-overlay supervision (crash → restart within seconds), plus Railway's `ON_FAILURE` restart policy.
- **Persistent memory**: `HERMES_HOME=/opt/data` (memories, skills, sessions `state.db`, cron jobs, pairing approvals, config) lives on a Railway volume.
- **Headless browser**: the official image ships a pinned full Chromium and the `agent-browser` driver, so the browser tools work in the container without any extra service (see "Browser design decision" below).

## Base market template

- **Base: `hermes-railway-template`** ("Hermes Agent by Nous Research", 5,929 recent deploys, the market leader by recent deploys). Kept the core idea: run the **official `nousresearch/hermes-agent` image** as an always-on gateway with a persistent volume and configuration through Railway variables. Its repo (`lovexbytes/hermes-railway-template`) has **no license**, so nothing was copied. It builds a derived image from the floating `latest` tag, rewrites `/data/.hermes/.env` on every boot, has no dashboard, no healthcheck, and requires OpenRouter + Telegram + a Telegram allowlist.
- `hermes-agent-ai` / `hermes-agent-nous-research` (praveen-ks-2001, 2,699 + 1,337 active): build Hermes from source on a Python 3.12 image (slow builds, a custom SQLite build) and wrap it with a ~4,400-line custom Flask admin app that reverse-proxies the native dashboard. They set `browser.backend: off` because their image has no Chromium, so **browser tools are disabled** there. Also no license, so nothing was copied. Idea taken: exposing the native Hermes dashboard is what users want; we now get it from upstream directly (`HERMES_DASHBOARD=1` plus the built-in auth gate) instead of a custom wrapper.
- No README text was reused.

## Pinned versions

| Service | Image | Tag | Release date | Checked |
|---|---|---|---|---|
| Hermes | `nousresearch/hermes-agent` (Docker Hub, official) | `v0.21.6` (current stable release "Hermes Agent v0.21.6"; `rc.*-v0.21.7` tags are pre-releases and were skipped) | 2026-10-08 | 2026-10-10 |

Upgrade: change the image tag to a newer `vX.Y.Z` from https://github.com/NousResearch/hermes-agent/releases, redeploy, then run `hermes config migrate` once via `railway ssh` if the release notes ask for it. Never run `hermes update` inside the container (the install tree is immutable in the official image; upstream refuses in-place updates on Docker).

## Architecture

```
 Telegram / Discord / Slack  ◄── outbound bot connections (no inbound ports needed)
                 ▲
                 │
   ┌─────────────┴──────────────────────────────────────────────┐
   │ Hermes (nousresearch/hermes-agent:v0.21.6)                  │
   │  railway-start.sh (Railway's init is PID 1, not s6)        │
   │   ├─ gateway run   (supervised: agent, cron, kanban)        │
   │   ├─ dashboard     (supervised: web UI + REST, :9119)       │
   │   └─ on demand: agent-browser + bundled headless Chromium   │
   │  volume /opt/data = HERMES_HOME (state.db, memories, skills) │
   └─────────────┬──────────────────────────────────────────────┘
                 │ HTTPS (Railway edge) → :9119, /api/health
            Dashboard login (username/password from variables)
```

One service. The gateway needs no inbound port; the public domain only serves the dashboard.

## Services

### Hermes

| Setting | Value |
|---|---|
| Source | Docker image `nousresearch/hermes-agent:v0.21.6` |
| Source | `services/hermes` — official image plus `railway-start.sh` as ENTRYPOINT, CMD `gateway run` |
| Healthcheck | `/api/health` (upstream's minimal, unauthenticated liveness probe on the dashboard), timeout 300 s (first boot seeds skills and runs state.db migrations) |
| Public domain | yes, target port **9119** (dashboard) |
| TCP proxy | none |
| Volume | `/opt/data` (official `HERMES_HOME`) |
| Restart policy | ON_FAILURE, 10 retries |
| Replicas | 1 (must stay 1: upstream forbids two gateways on one data directory) |

Why the wrapper: Railway runs containers under its own init (`podman-init` is PID 1), so the image's dispatcher takes its non-PID-1 path and skips s6-overlay. That path still bootstraps and runs the gateway, but no supervised services start — the dashboard never listened and the first deploy test failed its `/api/health` check. `railway-start.sh` repeats upstream's fallback (stage2 bootstrap, then `main-wrapper.sh`, which drops to the `hermes` user) and runs `hermes dashboard` in a restart loop as `hermes` next to it. Verified locally with `docker run --init` (non-PID-1): `/api/health` 200 after ~10 s, `/` redirects to the login page.

Variables (all have descriptions in `template.json`):

| Variable | Default | Notes |
|---|---|---|
| `OPENROUTER_API_KEY` | (required, user input) | The only required input. One key for all major models. |
| `TELEGRAM_BOT_TOKEN` | empty | Recommended first platform. |
| `TELEGRAM_ALLOWED_USERS` | empty | Empty = deny-all + DM pairing (approve in dashboard → Pairing). |
| `DISCORD_BOT_TOKEN`, `DISCORD_ALLOWED_USERS` | empty | Optional platform. |
| `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`, `SLACK_ALLOWED_USERS` | empty | Optional platform (Socket Mode needs both tokens). |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` | empty | Optional direct provider keys. More providers can be added on the dashboard's API Keys page. |
| `HERMES_INFERENCE_MODEL` | empty | Optional hard override of the model. |
| `HERMES_DASHBOARD` | `1` | Enables the official dashboard s6 service. |
| `HERMES_DASHBOARD_HOST` / `_PORT` | `0.0.0.0` / `9119` | Upstream defaults, made explicit. |
| `HERMES_DASHBOARD_PUBLIC_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Exact host for the Host/Origin guard and OAuth callbacks. |
| `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` | `admin` | Dashboard login. |
| `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | `${{secret(32)}}` | Generated. |
| `HERMES_DASHBOARD_BASIC_AUTH_SECRET` | `${{secret(64)}}` | Stable session-signing key (otherwise every restart logs you out). |
| `HERMES_DASHBOARD_OAUTH_CLIENT_ID` | empty | Optional upgrade to Nous Portal OAuth (`hermes dashboard register`). |
| `AGENT_BROWSER_ARGS` | `--no-sandbox,--disable-dev-shm-usage` | Container-safe Chromium flags (Railway has no `--shm-size`). |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `30` | Graceful stop for in-flight turns and SQLite checkpoints. |

Not set on purpose: `API_SERVER_*` (the OpenAI-compatible API server stays off; upstream notes that exposed API servers were an attack entry point in 2026), `GATEWAY_ALLOW_ALL_USERS` (would let anyone who finds the bot use your LLM key), `HERMES_UID/GID` (the upstream default 10000 is fine on a Railway volume).

### Browser design decision

Hermes supports four browser sources: its own packaged Chromium (default, driven by `agent-browser` / Browser Use mode), cloud providers (Browserbase, Browser Use, Firecrawl), Camofox, and a user-supplied CDP endpoint (`BROWSER_CDP_URL` / `browser.cdp_url`). We use the **packaged Chromium inside the official image** and deliberately do **not** add a Browserless sidecar:

- In v0.21.6 a CDP session is opened twice with the same URL: once by the `agent-browser` daemon and once by Hermes' CDP supervisor (dialogs, frame tree, and the fast path of `browser_console` evaluation), see `tools/browser_tool_session.py` and `tools/browser_tool_cdp.py`. Browserless v2 launches a **new browser per WebSocket connection**, so the supervisor would attach to a different, empty browser, and `browser_console(expression=...)` would evaluate against `about:blank`. That is a silent correctness bug, so a Browserless service would not be a "proper" setup.
- The packaged Chromium needs no extra service, starts per task and is reaped after `browser.inactivity_timeout`. Upstream sizing guidance: 1 GB without browser use, at least 2 GB with it, which Railway provides without configuration on Hobby.
- Users who want remote/stealth browsing can still set `BROWSERBASE_API_KEY` or `BROWSER_USE_API_KEY` (cloud providers have per-session CDP URLs and are supported upstream).

## First login

1. Open the service's public URL, sign in with `admin` and the value of `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` (Variables tab).
2. Status page: confirm the gateway is running and your platform shows as connected.
3. Config / Models: pick the default model (the stock config defaults to an Opus-class model through OpenRouter, which is expensive; choose deliberately).
4. DM your bot. Without an allowlist you receive a pairing code; approve it on **Pairing**.
5. Optional: Channels page to add more platforms, API Keys page for more providers, Cron for scheduled jobs, Skills for toolsets.

## Improvements over market templates

1. **Official image, pinned** (`v0.21.6`) instead of `latest` or a from-source build: reproducible deploys, no 5-10 minute Python/Node builds, upstream's SQLite fix and s6 supervision included.
2. **Native s6 supervision kept intact** through the image's own dispatcher, so the gateway and the dashboard are each restarted on crash without restarting the container.
3. **Official dashboard with the upstream auth gate** (generated password + stable session secret + exact public host) instead of a custom 4,400-line wrapper or no UI at all.
4. **Healthcheck** on `/api/health` (no market template had one that maps to an upstream endpoint).
5. **Browser tools actually work** (bundled Chromium + container-safe flags). The praveen templates turn them off; lovexbytes leaves them at the default without the container flags.
6. **Secure-by-default access**: deny-all + DM pairing with dashboard approvals; no allow-all switch; API server off.
7. **Only one required input** (OpenRouter key). Messaging platforms can be added at deploy time or later from the dashboard Channels page.
8. **Graceful redeploys** (`RAILWAY_DEPLOYMENT_DRAINING_SECONDS=30`) to protect `state.db`.

## Resource estimate

Railway prices: RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month.

| Service | Idle RAM / CPU | Typical RAM / CPU | Notes |
|---|---|---|---|
| Hermes (gateway + dashboard) | 0.7 GB / 0.05 vCPU | 1.4 GB avg, 2.5 GB peaks / 0.2 vCPU | Peaks while Chromium runs browser tasks or subagents work in parallel |
| Volume `/opt/data` | 0.5 GB | 2-3 GB | Grows with sessions, memories, skills, lazy-installed tool packages |

Estimated monthly cost: **idle ≈ $8**, **typical ≈ $18-20** (1.4 GB × $10 + 0.2 vCPU × $20 + 2 GB × $0.15). LLM usage is billed by your provider, not Railway.

Minimum plan: **Hobby**. Trial (1 GB per service) can boot the gateway, but the dashboard plus Chromium exceed 1 GB under browser use. Pro is only needed for more than the Hobby per-service limits.

## Verification checklist

- [ ] Deploy logs show s6 `/init` and `[stage2]` lines, then the gateway start banner; no "refusing to run as root" message.
- [ ] `GET https://<domain>/api/health` returns 200 without login; `GET /api/status` reports `auth_required: true` and provider `basic`.
- [ ] Dashboard login works with the generated password; the session survives a restart (proves `HERMES_DASHBOARD_BASIC_AUTH_SECRET`).
- [ ] Telegram (or the configured platform) bot replies after pairing approval; an unknown user gets a pairing code, not an answer.
- [ ] Browser tool: ask the agent "open https://example.com and tell me the page title"; it answers "Example Domain" without a browser error in the logs.
- [ ] Persistence: create a memory ("remember my favourite colour is teal"), redeploy, ask again; also confirm a cron job created in the dashboard survives the redeploy.
- [ ] Kill test: `railway ssh` → `pkill -f "gateway run"`; s6 restarts the gateway within seconds and the container stays up.

## Open questions

- Whether Railway containers allow Chromium's user-namespace sandbox could not be verified without a deploy. The template forces `--no-sandbox,--disable-dev-shm-usage`. If the sandbox does work, removing `AGENT_BROWSER_ARGS` restores Hermes' auto-detection.
- Upstream labels the username/password provider "trusted network only" and recommends Nous Portal OAuth for internet-facing dashboards. The template uses a 32-character generated password and HTTPS. Users who need stronger protection should register OAuth (`hermes dashboard register` via `railway ssh`, then set `HERMES_DASHBOARD_OAUTH_CLIENT_ID`) or remove the public domain when they are not using the dashboard.
- Railway's edge proxy is not loopback, so Hermes does not trust its `X-Forwarded-Proto`. Session cookies are therefore set without the `Secure` flag (still only sent over HTTPS by the browser). Login rate limiting counts per proxy IP. `dashboard.trusted_proxies` takes exact IPs/CIDRs only, and Railway's edge range is not documented.
- PID 1 behaviour of the start-command form (dispatcher sees `$$ = 1`) is inferred from Railway docs ("start command overrides ENTRYPOINT in exec form") and from the market leader, which also runs the dispatcher. If a deploy ever logs "container entrypoint is not PID 1", the gateway still runs but the dashboard is not started.
