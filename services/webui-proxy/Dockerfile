# Caddy 2.11.7 (Apache-2.0), official image.
FROM caddy:2.11.7-alpine@sha256:d8542f48d34a9cf4e4c11a478865229840e87e4c96ea3f439101f31a5d35f75f

# Overridden by the template with ${{Hermes.RAILWAY_PRIVATE_DOMAIN}}:${{Hermes.HERMES_WEBUI_PORT}}.
ENV HERMES_WEBUI_UPSTREAM=hermes.railway.internal:8787 \
    PORT=8080

COPY Caddyfile /etc/caddy/Caddyfile
RUN caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

EXPOSE 8080
# The base image runs: caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
