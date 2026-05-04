#!/usr/bin/env bash
# ha-run.sh — Home Assistant shim for FiestaBoard.
#
# Runs as root before the upstream /app/entrypoint.sh. Responsibilities:
#   1. Wire HA's /data volume into FiestaBoard's expected /app/data path.
#   2. Translate /data/options.json into the env vars the upstream image reads.
#   3. Query the Supervisor for the bound MQTT service (if any) and export
#      MQTT_* env vars so FiestaBoard's HA discovery starts with zero config.
#   4. Wire HA's homeassistant_api proxy into HOME_ASSISTANT_*.
#   5. exec into the upstream entrypoint with the original command.
#
# Designed to also run unit-testably: every external touchpoint (jq input
# path, supervisor URL, exec target) honours an env override so bats tests
# can stub them without docker.
set -euo pipefail

log() {
    printf '[ha-run] %s\n' "$*" >&2
}

# ---------------------------------------------------------------------------
# Configurable paths (overridable for tests). Resolved fresh in each function
# so tests can reassign HA_RUN_* between source-time and function call.
# ---------------------------------------------------------------------------
opts_file()      { echo "${HA_RUN_OPTIONS_FILE:-/data/options.json}"; }
data_dir()       { echo "${HA_RUN_DATA_DIR:-/data}"; }
app_data_dir()   { echo "${HA_RUN_APP_DATA_DIR:-/app/data}"; }
supervisor_url() { echo "${HA_RUN_SUPERVISOR_URL:-http://supervisor}"; }

# ---------------------------------------------------------------------------
# 1. Persistent data: link /app/data -> /data (the HA add-on volume).
# ---------------------------------------------------------------------------
link_data_dir() {
    local data_dir app_data_dir
    data_dir="$(data_dir)"
    app_data_dir="$(app_data_dir)"
    mkdir -p "${data_dir}"

    # If /app/data already points at /data, nothing to do.
    if [ -L "${app_data_dir}" ] && [ "$(readlink "${app_data_dir}")" = "${data_dir}" ]; then
        return 0
    fi

    # If /app/data exists as a directory in the upstream image (it does — the
    # upstream Dockerfile creates /app/data and declares VOLUME), migrate any
    # files baked in (none expected, but be safe), then replace with a symlink.
    if [ -d "${app_data_dir}" ] && [ ! -L "${app_data_dir}" ]; then
        if [ -n "$(ls -A "${app_data_dir}" 2>/dev/null)" ]; then
            log "migrating contents of ${app_data_dir} -> ${data_dir}"
            cp -an "${app_data_dir}"/. "${data_dir}"/ 2>/dev/null || true
        fi
        rm -rf "${app_data_dir}"
    elif [ -e "${app_data_dir}" ]; then
        rm -f "${app_data_dir}"
    fi

    ln -s "${data_dir}" "${app_data_dir}"
    log "linked ${app_data_dir} -> ${data_dir}"
}

# ---------------------------------------------------------------------------
# 2. Map /data/options.json to FiestaBoard env vars.
#
# Uses `jq -r` with `// empty` so unset/blank options become unset env vars
# (rather than an empty string that would override upstream defaults).
# ---------------------------------------------------------------------------
opt() {
    # opt <jq-path>   prints the value, or empty if missing/null.
    # We use `select(. != null)` rather than `// empty` because the alternative
    # operator `//` treats `false` as falsy and would swallow boolean-false
    # options like `mqtt_enabled: false`.
    local file
    file="$(opts_file)"
    if [ ! -f "${file}" ]; then
        return 0
    fi
    jq -r "${1} | select(. != null)" "${file}" 2>/dev/null
}

export_if_set() {
    local var="$1" value="$2"
    if [ -n "${value}" ]; then
        export "${var}=${value}"
    fi
}

apply_options() {
    if [ ! -f "$(opts_file)" ]; then
        log "no $(opts_file); skipping options mapping"
        return 0
    fi

    export_if_set BOARD_API_MODE          "$(opt '.board_api_mode')"
    export_if_set BOARD_HOST              "$(opt '.board_host')"
    export_if_set BOARD_LOCAL_API_KEY     "$(opt '.board_local_api_key')"
    export_if_set BOARD_READ_WRITE_KEY    "$(opt '.board_read_write_key')"
    export_if_set WEATHER_PROVIDER        "$(opt '.weather_provider')"
    export_if_set WEATHER_API_KEY         "$(opt '.weather_api_key')"
    export_if_set WEATHER_LOCATION        "$(opt '.weather_location')"
    export_if_set TIMEZONE                "$(opt '.timezone')"
    export_if_set FIESTABOARD_EXTERNAL_URL "$(opt '.fiestaboard_external_url')"
    export_if_set LOG_LEVEL               "$(opt '.log_level')"

    # mqtt_enabled is a bool; only export when true so we don't override
    # FiestaBoard's default-false behaviour when the user disabled it.
    local mqtt_flag
    mqtt_flag="$(opt '.mqtt_enabled')"
    if [ "${mqtt_flag}" = "true" ]; then
        export MQTT_ENABLED=true
    elif [ "${mqtt_flag}" = "false" ]; then
        export MQTT_ENABLED=false
    fi
}

# ---------------------------------------------------------------------------
# 3. Auto-wire HA's MQTT broker via the Supervisor services API.
#    Only runs when SUPERVISOR_TOKEN is present AND the user left MQTT enabled.
# ---------------------------------------------------------------------------
configure_mqtt() {
    if [ "${MQTT_ENABLED:-true}" = "false" ]; then
        log "mqtt_enabled=false; skipping MQTT auto-discovery"
        return 0
    fi
    local token
    token="${SUPERVISOR_TOKEN:-}"
    if [ -z "${token}" ]; then
        log "no SUPERVISOR_TOKEN; skipping MQTT auto-discovery"
        return 0
    fi

    local response
    response="$(curl -fsSL \
        -H "Authorization: Bearer ${token}" \
        "$(supervisor_url)/services/mqtt" 2>/dev/null)" || true

    if [ -z "${response}" ]; then
        log "MQTT service not bound (or supervisor unavailable); leaving MQTT defaults"
        return 0
    fi

    # Supervisor returns: { "result": "ok", "data": { "host": ..., "port": ..., "username": ..., "password": ..., "ssl": ..., "protocol": ... } }
    local host port username password
    host="$(echo "${response}"     | jq -r '.data.host     // empty')"
    port="$(echo "${response}"     | jq -r '.data.port     // empty')"
    username="$(echo "${response}" | jq -r '.data.username // empty')"
    password="$(echo "${response}" | jq -r '.data.password // empty')"

    if [ -z "${host}" ]; then
        log "MQTT service response missing host; leaving MQTT defaults"
        return 0
    fi

    export MQTT_ENABLED=true
    export MQTT_BROKER_HOST="${host}"
    [ -n "${port}" ]     && export MQTT_BROKER_PORT="${port}"
    [ -n "${username}" ] && export MQTT_USERNAME="${username}"
    [ -n "${password}" ] && export MQTT_PASSWORD="${password}"
    log "MQTT auto-configured: host=${host} port=${port:-1883}"
}

# ---------------------------------------------------------------------------
# 4. Wire HA core API (homeassistant_api: true).
# ---------------------------------------------------------------------------
configure_home_assistant_api() {
    local token
    token="${SUPERVISOR_TOKEN:-}"
    if [ -z "${token}" ]; then
        return 0
    fi
    # Don't override if the user provided their own values via add-on options.
    if [ -z "${HOME_ASSISTANT_BASE_URL:-}" ]; then
        local sup
        sup="$(supervisor_url)"
        export HOME_ASSISTANT_BASE_URL="${sup}/core"
    fi
    if [ -z "${HOME_ASSISTANT_ACCESS_TOKEN:-}" ]; then
        export HOME_ASSISTANT_ACCESS_TOKEN="${token}"
    fi
}

# ---------------------------------------------------------------------------
# 5. Hand off to upstream entrypoint with the supervisord command.
# ---------------------------------------------------------------------------
main() {
    link_data_dir
    apply_options
    configure_mqtt
    configure_home_assistant_api

    if [ "$#" -eq 0 ]; then
        log "no CMD provided; defaulting to upstream entrypoint + supervisord"
        set -- /app/entrypoint.sh supervisord -c /app/supervisord.conf
    fi

    log "exec: $*"
    exec "$@"
}

# When sourced for tests (HA_RUN_SOURCE_ONLY=1), define functions but don't run.
if [ "${HA_RUN_SOURCE_ONLY:-0}" != "1" ]; then
    main "$@"
fi
