# Deploy and Host Hermes Agent with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/hermes-agent-v021-always-on-telegram-dis?referralCode=20H68q)

Run Hermes Agent, the open-source self-improving agent from Nous Research, as an always-on assistant on Railway. Talk to it on Telegram, Discord or Slack, or chat in the browser and on your phone with Hermes WebUI. Memory, skills and schedules persist on a volume, a headless Chromium handles web tasks, and the official dashboard is included.

## About Hosting Hermes Agent

Hermes Agent runs as a long-lived gateway: it holds outbound connections to your chat platforms, calls the LLM provider you configure, uses tools (terminal, files, web, browser) and stores what it learns in its home directory. Hosting it yourself means a machine that never sleeps, durable storage for its SQLite state and memories, and safe ways to administer and talk to it. This community template runs the official `nousresearch/hermes-agent` image pinned to a release, mounts a Railway volume as `HERMES_HOME`, and runs three things side by side: the gateway, the official web dashboard, and Hermes WebUI, a community chat interface that shares the same memory, skills and sessions. Both web interfaces are protected by generated passwords.

## Common Use Cases

- A personal research and productivity assistant you reach from Telegram, Discord, Slack or a browser tab on your phone
- Long working sessions in the browser: chat with streaming replies, browse sessions, edit files in the agent's workspace
- Scheduled jobs: daily briefings, website monitoring, feed summaries and recurring reports delivered to a chat
- Web tasks that need a real browser: reading dynamic pages, filling forms, checking a deploy
- A team helper in a Slack or Discord channel, restricted to approved members via pairing or allowlists

## Dependencies for Hermes Agent Hosting

- An LLM provider key (the template asks for an OpenRouter key; Anthropic, OpenAI and many others can be added later)
- Optional: a bot token for Telegram, Discord or Slack, at deploy time or later in the dashboard (the WebUI works without one)
- A Railway volume for `/opt/data` (included)

### Deployment Dependencies

- Hermes Agent repository and releases: https://github.com/NousResearch/hermes-agent
- Docker guide: https://hermes-agent.nousresearch.com/docs/user-guide/docker
- Web dashboard and authentication: https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard
- Environment variable reference: https://hermes-agent.nousresearch.com/docs/reference/environment-variables
- Hermes WebUI (community project, MIT): https://github.com/nesquena/hermes-webui
- Hermes WebUI Docker guide: https://github.com/nesquena/hermes-webui/blob/master/docs/docker.md
- OpenRouter keys: https://openrouter.ai/keys
- Telegram BotFather: https://t.me/BotFather

### Implementation Details

| Service | Image | Purpose |
|---|---|---|
| Hermes | `nousresearch/hermes-agent` v0.21.7 + Hermes WebUI v0.52.113 | Gateway (agent, cron, kanban), official dashboard on the public URL (port 9119), Hermes WebUI on private port 8787, bundled headless Chromium, volume at `/opt/data` |
| Hermes WebUI | `caddy:2.11.7-alpine` | Small reverse proxy that gives the WebUI its own HTTPS address and forwards to the Hermes service over the private network |

Hermes WebUI runs inside the Hermes service because it drives the agent in-process and reads the same home directory (config, sessions, memory, skills); a Railway volume can only be attached to one service. Chats started in the WebUI use the same model, keys, tools and browser as your Telegram bot, and bot conversations show up in the WebUI sidebar.

**First login**

1. Dashboard: open the **Hermes** service URL and sign in as `admin` with the password in `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` (Railway → Hermes → Variables). Choose your default model; the stock default is a premium model, so pick one that fits your budget.
2. Web chat: open the **Hermes WebUI** service URL (`https://{your-webui-domain}`) and enter the password from `HERMES_WEBUI_PASSWORD`, which is also on the **Hermes** service's Variables tab. On a phone, use "Add to Home Screen" for an app-like shortcut.
3. Messaging: DM your bot. Unknown users receive a pairing code, which you approve on the dashboard's **Pairing** page. Set `TELEGRAM_ALLOWED_USERS` (or the Discord/Slack equivalent) to skip pairing for known IDs.
4. Add more platforms on **Channels**, more providers on **API Keys**, scheduled jobs on **Cron**.

The WebUI needs about a minute after a deploy; until then its URL shows a short "not reachable yet" notice. To turn it off, set `HERMES_WEBUI=0` on the Hermes service. Deployments created before the WebUI was added keep it off until `HERMES_WEBUI=1` and a `HERMES_WEBUI_PASSWORD` are set and the proxy service is added.

**Scaling**: Hermes is a single-writer process. Keep one replica and scale vertically (Railway gives the service more RAM/CPU automatically up to your plan limit). The proxy needs no scaling. For separate personas, use Hermes profiles inside the same service rather than extra replicas. Never point two gateways at one data directory.

**Pinning and upgrades**: all images are pinned by tag and digest in `services/hermes/Dockerfile` and `services/webui-proxy/Dockerfile`. Hermes WebUI and Hermes Agent are developed separately and should be upgraded together to versions released close to each other. After an upgrade, run `hermes config migrate` via `railway ssh` if the release notes say so. Do not run `hermes update` inside the container.

**Security notes**: both interfaces can read and change API keys and run tools, and the WebUI includes a web terminal, so keep both passwords private. The WebUI never starts without a password. For an internet-facing dashboard, upstream recommends Nous Portal OAuth: run `hermes dashboard register` via `railway ssh` and set `HERMES_DASHBOARD_OAUTH_CLIENT_ID`. The OpenAI-compatible API server is disabled by default.

### Why Deploy Hermes Agent on Railway?

An agent that learns over time is only useful if it is always reachable and never loses its memory. Railway runs Hermes around the clock with a persistent volume, private networking between services, automatic restarts, logs and SSH access, without maintaining a VPS. You pay only for the resources the agent actually uses.
