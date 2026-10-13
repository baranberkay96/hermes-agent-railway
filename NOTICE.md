# NOTICE: Hermes Agent template

## Software deployed

| Component | Source | License | How it is used |
|---|---|---|---|
| Hermes Agent | https://github.com/NousResearch/hermes-agent, image `nousresearch/hermes-agent:rc.15-v0.21.7` (release v0.21.7, digest-pinned) | MIT, Copyright (c) 2025 Nous Research | Official image used as the base of `services/hermes`, unmodified. No upstream files are copied into this template. |
| Hermes WebUI | https://github.com/nesquena/hermes-webui, image `ghcr.io/nesquena/hermes-webui:0.52.113` (release v0.52.113, digest-pinned) | MIT, Copyright (c) 2025 Hermes Web UI Contributors | The image's application directory (`/apptoo`) is copied unmodified into the Hermes image at build time (`COPY --from`), which redistributes it; its LICENSE file travels with it. No WebUI files are stored in this repository. |
| PyYAML 6.0.3 | https://pypi.org/project/PyYAML/ (installed from PyPI at build time with the `uv` binary of the WebUI image; uv is used in a build stage only and not shipped) | MIT, Copyright (c) 2017-2021 Ingy döt Net, Copyright (c) 2006-2016 Kirill Simonov | Dependency of Hermes WebUI, placed in `/opt/hermes-webui-deps`, unmodified. |
| Caddy | https://github.com/caddyserver/caddy, image `caddy:2.11.7-alpine` (Docker Official Image) | Apache-2.0 | Base image of `services/webui-proxy`, unmodified. The `Caddyfile` was written for this template. |

Hermes Agent and Nous Research are trademarks of their respective owners. Hermes WebUI is an independent community project. This is a community template and is not affiliated with or endorsed by Nous Research or the Hermes WebUI maintainers.

## Upstream files checked

Hermes Agent (tag `v0.21.6` checked 2026-10-10; `v0.21.7` checked 2026-10-13):

- `Dockerfile`: entrypoint (`docker/entrypoint-dispatch.sh`), `HERMES_HOME=/opt/data`, sealed venv `/opt/hermes/.venv`, bundled Chromium, `VOLUME /opt/data`
- `docker/entrypoint-dispatch.sh`, `docker/main-wrapper.sh`, `docker/stage2-hook.sh`, `docker/s6-rc.d/dashboard/run`: identical in v0.21.6 and v0.21.7
- `.github/workflows/docker.yml`, `.github/workflows/stable-release.yml`, `scripts/releases/docker.py`: staged Docker publication (immutable `rc.N-vX.Y.Z` tags, `stable`/`latest` aliases); git tag `v0.21.7` receipt (claim tag `rc.15-v0.21.7`, docker manifest digest `sha256:444b42594e7f…`)
- `tools/approval.py` (v0.21.7): names the WebUI imports, to assess WebUI compatibility
- `hermes_cli/web_server.py`, `hermes_cli/dashboard_auth/public_paths.py`, `website/docs/user-guide/docker.md`, `.../features/web-dashboard.md`, `.../features/browser.md`, `website/docs/reference/environment-variables.md`

Hermes WebUI (tag `v0.52.113`, checked 2026-10-13; repository `master` read for compose files and docs):

- `docker-compose.yml`, `docker-compose.two-container.yml`, `docker-compose.three-container.yml`, `docs/docker.md`: in-process agent, shared Hermes home volume, optional gateway API (`HERMES_API_URL`, `API_SERVER_KEY`)
- `Dockerfile`, `docker_init.bash`: application in `/apptoo`, default `HERMES_WEBUI_HOST/PORT`, `/health`
- `server.py`: stdlib `ThreadingHTTPServer`, IPv6 socket when the host contains `:`; warns (does not refuse) when bound publicly without a password
- `api/auth.py`: `HERMES_WEBUI_PASSWORD` (PBKDF2), public path list, signed session cookies, `HERMES_WEBUI_SECURE`, login rate limit keyed on the socket peer
- `api/routes.py`: Origin/Host CSRF check, onboarding gate, forwarded-header trust settings
- `api/config.py`, `api/paths.py`: agent/python discovery (`HERMES_WEBUI_AGENT_DIR`, `HERMES_WEBUI_PYTHON`), state and workspace directories
- `api/streaming.py`, `api/route_approvals.py`, `CHANGELOG.md`: agent compatibility (see TEMPLATE.md, Open questions)

## Market templates and repositories reviewed (ideas only, nothing copied)

| Template / repo | License | Use |
|---|---|---|
| `hermes-railway-template` / `lovexbytes/hermes-railway-template` | none (all rights reserved) | Approach (official image + volume + env config). |
| `hermes-agent-ai`, `hermes-agent-nous-research` / `praveen-ks-2001/hermes-agent-template` | none | Feature expectations (dashboard access). |
| `hermes-agent-all-in-one` / `protemplate/hermes-agent-railway` | none | Confirmed that the WebUI shares the agent's home directory in one container. |
| `hermes-agent-with-official-dashboard` / `mazshakibaii/hermes-agent-railway` | none | Dashboard-behind-proxy approach (not used). |
| `hermes-agent-official` (official image, start command) | n/a (config only) | Reviewed; its allow-all and API-server defaults were not adopted. |

All template files (TEMPLATE.md, template.json, README.md, this NOTICE, `services/*/Dockerfile`, `railway-start.sh`, `Caddyfile`) were written for this package.

Hermes Agent `pyproject.toml` and `uv.lock` (tag `v0.21.7`) were checked to confirm that cryptography is in the image's venv and PyYAML is not.
