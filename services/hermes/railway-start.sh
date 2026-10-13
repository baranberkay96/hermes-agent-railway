#!/bin/sh
# shellcheck shell=sh
# Railway runs containers under its own init, so this entrypoint is not PID 1.
# Upstream's dispatcher then skips s6-overlay and its supervised services, which
# means the dashboard never starts. Do what upstream's non-PID-1 fallback does
# (stage2 bootstrap, then the main wrapper) and keep the side services alive in
# restart loops next to the gateway:
#   - the official Hermes dashboard (HERMES_DASHBOARD, port 9119)
#   - Hermes WebUI, the browser/phone chat UI (HERMES_WEBUI, port 8787)
set -e

export PATH="/command:/package/admin/s6/command:${PATH}"
/opt/hermes/docker/stage2-hook.sh

is_on() {
    case "$1" in
        1|true|TRUE|True|yes|YES|Yes|on|ON|On) return 0 ;;
    esac
    return 1
}

# Hermes WebUI runs the agent in-process against the same HERMES_HOME (/opt/data),
# so chats, memory, skills, cron jobs and provider keys are shared with the
# gateway and the dashboard. It is started only with a password (fail closed):
# the WebUI itself would serve without one.
if is_on "${HERMES_WEBUI:-}"; then
    if [ -z "$(printf '%s' "${HERMES_WEBUI_PASSWORD:-}" | tr -d '[:space:]')" ]; then
        echo "[railway-start] Hermes WebUI not started: HERMES_WEBUI_PASSWORD is empty" >&2
    else
        (
            export HOME=/opt/data
            # "::" is dual-stack here (threaded stdlib server), so the
            # Hermes WebUI proxy service reaches it over Railway's private
            # network on IPv4 and IPv6.
            export HERMES_WEBUI_HOST="${HERMES_WEBUI_HOST:-::}"
            export HERMES_WEBUI_PORT="${HERMES_WEBUI_PORT:-8787}"
            export HERMES_WEBUI_STATE_DIR="${HERMES_WEBUI_STATE_DIR:-/opt/data/webui}"
            export HERMES_WEBUI_AGENT_DIR=/opt/hermes
            export HERMES_WEBUI_PYTHON=/opt/hermes/.venv/bin/python
            # PyYAML for the WebUI, installed beside (not into) the sealed venv.
            export PYTHONPATH="/opt/hermes-webui-deps${PYTHONPATH:+:${PYTHONPATH}}"
            # Railway serves the WebUI over HTTPS only: mark session cookies Secure.
            export HERMES_WEBUI_SECURE="${HERMES_WEBUI_SECURE:-1}"
            cd /opt/data
            while true; do
                s6-setuidgid hermes /opt/hermes/.venv/bin/python \
                    /opt/hermes-webui/server.py || true
                echo "[railway-start] Hermes WebUI exited; restarting in 5s" >&2
                sleep 5
            done
        ) &
    fi
fi
# Only the WebUI process needs its password; keep it out of the gateway's and
# dashboard's environments (and therefore out of their tool subprocesses).
unset HERMES_WEBUI_PASSWORD

if is_on "${HERMES_DASHBOARD:-}"; then
    (
        export HOME=/opt/data
        cd /opt/data
        while true; do
            s6-setuidgid hermes hermes dashboard \
                --host "${HERMES_DASHBOARD_HOST:-0.0.0.0}" \
                --port "${HERMES_DASHBOARD_PORT:-9119}" --no-open || true
            echo "[railway-start] dashboard exited; restarting in 5s" >&2
            sleep 5
        done
    ) &
fi

exec /opt/hermes/docker/main-wrapper.sh "$@"
