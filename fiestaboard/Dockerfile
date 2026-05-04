# https://developers.home-assistant.io/docs/apps/configuration#app-dockerfile
# This Dockerfile is a thin wrapper around the upstream FiestaBoard image.
# It adds:
#   - jq (used by ha-run.sh to parse /data/options.json)
#   - curl (used by ha-run.sh to query the Supervisor API for MQTT service info)
#     -> already present in the upstream image, but listed defensively.
#   - the rootfs/ overlay containing /usr/local/bin/ha-run.sh
# Then it overrides CMD so the Home Assistant Supervisor launches our shim
# instead of supervisord directly. The shim exec's into FiestaBoard's
# upstream /app/entrypoint.sh after exporting env vars.
ARG BUILD_FROM=fiestaboard/fiestaboard:latest
# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# HA Supervisor launches add-on containers as root; the upstream entrypoint
# performs its own gosu root->appuser handoff. Switching back to root here is
# intentional so our shim can manage symlinks under /app and write env files.
# hadolint ignore=DL3002
USER root

# hadolint ignore=DL3008,DL3015
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs/ /

RUN chmod +x /usr/local/bin/ha-run.sh

# Build-time metadata. The CI build action injects io.hass.* labels at push time.
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

LABEL \
    org.opencontainers.image.title="Home Assistant App: FiestaBoard" \
    org.opencontainers.image.description="Run FiestaBoard as a Home Assistant Supervisor add-on" \
    org.opencontainers.image.source="https://github.com/Fiestaboard/FiestaBoard-Home-Assistant-App" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.vendor="FiestaBoard" \
    org.opencontainers.image.revision="${BUILD_REF}" \
    org.opencontainers.image.version="${BUILD_VERSION}" \
    org.opencontainers.image.created="${BUILD_DATE}"

# Our shim must run BEFORE the upstream /app/entrypoint.sh so it can:
#   1. Symlink /app/data -> /data (HA's persistent volume) before upstream
#      mkdirs/chowns /app/data.
#   2. Translate /data/options.json into the env vars upstream consumes.
#   3. Query the Supervisor for the MQTT service binding and HA API token.
# After that, ha-run.sh `exec`s the upstream entrypoint with the original
# command, preserving upstream's root->appuser gosu handoff and supervisord
# launch.
ENTRYPOINT ["/usr/local/bin/ha-run.sh"]
CMD ["/app/entrypoint.sh", "supervisord", "-c", "/app/supervisord.conf"]
