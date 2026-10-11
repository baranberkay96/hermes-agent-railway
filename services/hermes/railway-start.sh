#!/bin/sh
# shellcheck shell=sh
# Railway runs containers under its own init, so this entrypoint is not PID 1.
# Upstream's dispatcher then skips s6-overlay and its supervised services, which
# means the dashboard never starts. Do what upstream's non-PID-1 fallback does
# (stage2 bootstrap, then the main wrapper) and keep the dashboard alive in a
# restart loop next to the gateway.
set -e

export PATH="/command:/package/admin/s6/command:${PATH}"
/opt/hermes/docker/stage2-hook.sh

case "${HERMES_DASHBOARD:-}" in
    1|true|TRUE|True|yes|YES|Yes)
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
        ;;
esac

exec /opt/hermes/docker/main-wrapper.sh "$@"
