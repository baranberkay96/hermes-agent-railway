# NOTICE: Hermes Agent template

## Software deployed

| Component | Source | License | How it is used |
|---|---|---|---|
| Hermes Agent | https://github.com/NousResearch/hermes-agent, image `nousresearch/hermes-agent:v0.21.6` | MIT, Copyright (c) 2025 Nous Research | Official image pulled unmodified. No upstream files are copied into this template. |

Hermes Agent and Nous Research are trademarks of their respective owners. This is a community template and is not affiliated with or endorsed by Nous Research.

## Upstream files checked (tag `v0.21.6`, checked 2026-10-10)

- `Dockerfile`: entrypoint (`docker/entrypoint-dispatch.sh`), `HERMES_HOME=/opt/data`, bundled Chromium (`PLAYWRIGHT_BROWSERS_PATH=/opt/hermes/tools`), `VOLUME /opt/data`
- `docker-compose.yml`: gateway (`gateway run`) and dashboard services, security notes
- `docker/s6-rc.d/dashboard/run`: `HERMES_DASHBOARD`, `HERMES_DASHBOARD_HOST/PORT`, auth-gate requirements
- `docker/main-wrapper.sh`, `docker/stage2-hook.sh`: argument routing, privilege drop, targeted volume ownership
- `hermes_cli/web_server.py`, `hermes_cli/dashboard_auth/public_paths.py`: Host-header guard, unauthenticated `/api/health`
- `tools/browser_tool_cdp.py`, `tools/browser_tool_session.py`: CDP override resolution (reason a Browserless sidecar was not added)
- `website/docs/user-guide/docker.md`, `.../features/web-dashboard.md`, `.../features/browser.md`, `website/docs/reference/environment-variables.md`

## Market templates and repositories reviewed (ideas only, nothing copied)

| Template / repo | License | Use |
|---|---|---|
| `hermes-railway-template` / `lovexbytes/hermes-railway-template` | none (all rights reserved) | Read for approach (official image + volume + env config). No files or text copied. |
| `hermes-agent-ai`, `hermes-agent-nous-research` / `praveen-ks-2001/hermes-agent-template` | none (all rights reserved) | Read for feature expectations (dashboard access). No files or text copied. |

All template files (TEMPLATE.md, template.json, README.md, this NOTICE) were written for this package.
