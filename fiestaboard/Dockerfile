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
#
# The default below is the SINGLE SOURCE OF TRUTH for the pinned upstream
# FiestaBoard release (build.yaml is gone; the HA builder deprecated it).
# The Upstream bump workflow (.github/workflows/upstream-bump.yaml) greps and
# seds this line, so keep it in the `ARG BUILD_FROM=fiestaboard/fiestaboard:X`
# form. CI does not override BUILD_FROM; both arches use this multi-arch base.
ARG BUILD_FROM=fiestaboard/fiestaboard:8.1.2
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

# Build-time metadata. CI's build-image action (builder.yaml) always passes
# the BUILD_ARCH and BUILD_VERSION build args and injects the dynamic
# io.hass.arch / io.hass.version / org.opencontainers.image.{created,version,
# source} labels at build time; BUILD_REF is passed explicitly by builder.yaml.
# The static labels (formerly split between build.yaml and this file) live here.
ARG BUILD_ARCH
ARG BUILD_REF
ARG BUILD_VERSION

LABEL \
    io.hass.name="FiestaBoard" \
    io.hass.description="Run FiestaBoard as a Home Assistant Supervisor add-on" \
    io.hass.type="addon" \
    io.hass.url="https://github.com/Fiestaboard/FiestaBoard-Home-Assistant-App/tree/main/fiestaboard" \
    org.opencontainers.image.title="Home Assistant App: FiestaBoard" \
    org.opencontainers.image.description="Run FiestaBoard as a Home Assistant Supervisor add-on" \
    org.opencontainers.image.source="https://github.com/Fiestaboard/FiestaBoard-Home-Assistant-App" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.vendor="FiestaBoard" \
    org.opencontainers.image.revision="${BUILD_REF}" \
    org.opencontainers.image.version="${BUILD_VERSION}"

# Our shim must run BEFORE the upstream /app/entrypoint.sh so it can:
#   1. Translate /data/options.json into the env vars upstream consumes.
#   2. Query the Supervisor for the MQTT service binding and HA API token.
# After that, ha-run.sh `exec`s the upstream entrypoint with the original
# command, preserving upstream's root->appuser gosu handoff and supervisord
# launch. Persistent data at /app/data is mounted directly by HA Supervisor
# via the `map: { type: addon_config, path: /app/data }` directive in
# config.yaml, so the shim does not manage that path.
ENTRYPOINT ["/usr/local/bin/ha-run.sh"]
CMD ["/app/entrypoint.sh", "supervisord", "-c", "/app/supervisord.conf"]
