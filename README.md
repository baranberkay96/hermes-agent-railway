# Deploy and Host Hermes Agent with Railway

Run Hermes Agent, the open-source self-improving agent from Nous Research, as an always-on assistant on Railway. It answers you on Telegram, Discord or Slack, keeps its memory, skills and schedules on a persistent volume, browses the web with a built-in headless Chromium and ships with the official web dashboard.

## About Hosting Hermes Agent

Hermes Agent runs as a long-lived gateway: it holds outbound connections to your chat platforms, calls the LLM provider you configure, uses tools (terminal, files, web, browser) and stores what it learns in `~/.hermes`. Hosting it yourself means you need a machine that never sleeps, durable storage for its SQLite state and memories, and a safe way to administer it. This community template runs the official `nousresearch/hermes-agent` image pinned to a release, keeps the gateway and dashboard under the image's own s6 supervisor, mounts a Railway volume as `HERMES_HOME`, and protects the dashboard with a generated password.

## Common Use Cases

- A personal research and productivity assistant you message from Telegram, Discord or Slack, day or night
- Scheduled jobs: daily briefings, monitoring a website, summarising feeds, recurring reports delivered to a chat
- Web tasks that need a real browser: reading dynamic pages, filling forms, checking a deploy
- A team helper in a Slack or Discord channel, restricted to approved members via pairing or allowlists

## Dependencies for Hermes Agent Hosting

- An LLM provider key (the template asks for an OpenRouter key; Anthropic, OpenAI and many others can be added later)
- A bot token for at least one chat platform (Telegram, Discord or Slack), at deploy time or later in the dashboard
- A Railway volume for `/opt/data` (included)

### Deployment Dependencies

- Hermes Agent repository and releases: https://github.com/NousResearch/hermes-agent
- Docker guide: https://hermes-agent.nousresearch.com/docs/user-guide/docker
- Web dashboard and authentication: https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard
- Environment variable reference: https://hermes-agent.nousresearch.com/docs/reference/environment-variables
- OpenRouter keys: https://openrouter.ai/keys
- Telegram BotFather: https://t.me/BotFather

### Implementation Details

| Service | Image | Purpose |
|---|---|---|
| Hermes | `nousresearch/hermes-agent:v0.21.6` | Gateway (agent, cron, kanban) + official dashboard on port 9119, bundled headless Chromium, volume at `/opt/data` |

**First login**

1. Open the service URL and sign in as `admin` with the password in `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` (Railway → service → Variables).
2. Choose your default model in the dashboard. The stock default is a premium model, so pick one that fits your budget.
3. Message your bot. Unknown users receive a pairing code, which you approve on the dashboard's **Pairing** page. Set `TELEGRAM_ALLOWED_USERS` (or the Discord/Slack equivalent) to skip pairing for known IDs.
4. Add more platforms on **Channels**, more providers on **API Keys**, scheduled jobs on **Cron**.

**Scaling**: Hermes is a single-writer process. Keep one replica and scale vertically (Railway gives the service more RAM/CPU automatically up to your plan limit). For separate personas, use Hermes profiles inside the same service rather than extra replicas. Never point two gateways at one data directory.

**Pinning and upgrades**: the image tag is pinned. To upgrade, change the tag to a newer release from the GitHub releases page and redeploy, then run `hermes config migrate` via `railway ssh` if the release notes say so. Do not run `hermes update` inside the container.

**Security notes**: the dashboard can read and change API keys, so keep the generated password private. For an internet-facing dashboard, upstream recommends Nous Portal OAuth: run `hermes dashboard register` via `railway ssh` and set `HERMES_DASHBOARD_OAUTH_CLIENT_ID`. The OpenAI-compatible API server is disabled by default.

### Why Deploy Hermes Agent on Railway?

An agent that learns over time is only useful if it is always reachable and never loses its memory. Railway runs Hermes around the clock with a persistent volume, automatic restarts, logs and SSH access, without maintaining a VPS. You pay only for the resources the agent actually uses.
