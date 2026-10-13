# Hermes WebUI (MIT, github.com/nesquena/hermes-webui), stable release v0.52.113
# (image tags carry no "v"). Only its source tree (/apptoo) and its uv binary
# are used; the WebUI runs on the Hermes venv below. Digest-pinned because the
# WebUI's floating tags move daily.
FROM ghcr.io/nesquena/hermes-webui:0.52.113@sha256:48ba6ee4a837079955c00e997b751065cc0324ae6eaa0f2fec592c8f4b2a746e AS webui

# Hermes Agent v0.21.7. Upstream's staged release flow publishes each release
# under its immutable attempt tag (rc.15-v0.21.7 is the candidate the v0.21.7
# release receipt names) and then moves :stable/:latest onto it. There is no
# plain v0.21.7 tag on Docker Hub, so pin the attempt tag plus its digest.
FROM nousresearch/hermes-agent:rc.15-v0.21.7@sha256:444b42594e7f467425872fc35e077a227d377f0fe0726bc818706d62175fad8b AS hermes

# The WebUI needs PyYAML and cryptography next to the agent. cryptography is in
# the Hermes venv; PyYAML is not (Hermes uses ruamel.yaml). The venv is sealed,
# so install PyYAML into a separate directory for the interpreter's own ABI and
# put it on the WebUI process's PYTHONPATH only (see railway-start.sh).
# (--target never writes into the venv; --break-system-packages only keeps uv
# from refusing an interpreter that is marked as externally managed.)
FROM hermes AS webui-deps
COPY --from=webui /usr/local/bin/uv /usr/local/bin/uv-webui
RUN uv-webui pip install --no-cache --break-system-packages \
        --python /opt/hermes/.venv/bin/python \
        --target /opt/hermes-webui-deps "pyyaml==6.0.3"

FROM hermes
# Read-only for the runtime user: the agent cannot rewrite the UI it is driven from.
COPY --from=webui --chown=root:root /apptoo /opt/hermes-webui
COPY --from=webui-deps --chown=root:root /opt/hermes-webui-deps /opt/hermes-webui-deps

# Fail the build if the WebUI could not import its dependencies or the agent layout moved.
RUN PYTHONPATH=/opt/hermes-webui-deps /opt/hermes/.venv/bin/python -c "import yaml, cryptography" \
    && test -f /opt/hermes-webui/server.py \
    && test -f /opt/hermes/run_agent.py

COPY --chmod=0755 railway-start.sh /opt/hermes/railway-start.sh

ENTRYPOINT ["/opt/hermes/railway-start.sh"]
CMD ["gateway", "run"]
