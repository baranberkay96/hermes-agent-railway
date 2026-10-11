FROM nousresearch/hermes-agent:v0.21.6

COPY --chmod=0755 railway-start.sh /opt/hermes/railway-start.sh

ENTRYPOINT ["/opt/hermes/railway-start.sh"]
CMD ["gateway", "run"]
