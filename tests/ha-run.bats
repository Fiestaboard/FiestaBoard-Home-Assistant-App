#!/usr/bin/env bats
# Unit tests for fiestaboard/rootfs/usr/local/bin/ha-run.sh.
# We source the script with HA_RUN_SOURCE_ONLY=1 to load functions without
# triggering main(), then drive each function with stub paths/env.

setup() {
    SCRIPT="${BATS_TEST_DIRNAME}/../fiestaboard/rootfs/usr/local/bin/ha-run.sh"
    TMP="$(mktemp -d)"
    export HA_RUN_OPTIONS_FILE="${TMP}/options.json"
    export HA_RUN_DATA_DIR="${TMP}/data"
    export HA_RUN_APP_DATA_DIR="${TMP}/app-data"
    export HA_RUN_SUPERVISOR_URL="http://127.0.0.1:0"  # invalid by default
    unset SUPERVISOR_TOKEN
    unset MQTT_ENABLED MQTT_BROKER_HOST MQTT_BROKER_PORT MQTT_USERNAME MQTT_PASSWORD
    unset BOARD_API_MODE BOARD_HOST BOARD_LOCAL_API_KEY BOARD_READ_WRITE_KEY
    unset WEATHER_PROVIDER WEATHER_API_KEY WEATHER_LOCATION TIMEZONE
    unset FIESTABOARD_EXTERNAL_URL LOG_LEVEL
    unset HOME_ASSISTANT_BASE_URL HOME_ASSISTANT_ACCESS_TOKEN

    # shellcheck disable=SC1090
    HA_RUN_SOURCE_ONLY=1 source "${SCRIPT}"
}

teardown() {
    [ -n "${SUPERVISOR_PID:-}" ] && kill "${SUPERVISOR_PID}" 2>/dev/null || true
    rm -rf "${TMP}"
}

# ---------------------------------------------------------------------------
# link_data_dir
# ---------------------------------------------------------------------------

@test "link_data_dir creates /app/data symlink to /data" {
    link_data_dir
    [ -L "${HA_RUN_APP_DATA_DIR}" ]
    [ "$(readlink "${HA_RUN_APP_DATA_DIR}")" = "${HA_RUN_DATA_DIR}" ]
}

@test "link_data_dir is idempotent" {
    link_data_dir
    link_data_dir
    [ -L "${HA_RUN_APP_DATA_DIR}" ]
    [ "$(readlink "${HA_RUN_APP_DATA_DIR}")" = "${HA_RUN_DATA_DIR}" ]
}

@test "link_data_dir migrates existing /app/data contents" {
    mkdir -p "${HA_RUN_APP_DATA_DIR}"
    echo "preserved" > "${HA_RUN_APP_DATA_DIR}/marker"
    link_data_dir
    [ -L "${HA_RUN_APP_DATA_DIR}" ]
    [ -f "${HA_RUN_DATA_DIR}/marker" ]
    [ "$(cat "${HA_RUN_DATA_DIR}/marker")" = "preserved" ]
}

# ---------------------------------------------------------------------------
# apply_options — env-var mapping
# ---------------------------------------------------------------------------

@test "apply_options exports each set option" {
    cat > "${HA_RUN_OPTIONS_FILE}" <<'JSON'
{
  "board_api_mode": "cloud",
  "board_host": "192.168.1.50",
  "board_local_api_key": "lkey",
  "board_read_write_key": "rwkey",
  "weather_provider": "openweathermap",
  "weather_api_key": "wkey",
  "weather_location": "San Francisco, CA",
  "timezone": "America/Los_Angeles",
  "mqtt_enabled": true,
  "fiestaboard_external_url": "http://ha.local:4420",
  "log_level": "debug"
}
JSON
    apply_options
    [ "${BOARD_API_MODE}"           = "cloud" ]
    [ "${BOARD_HOST}"               = "192.168.1.50" ]
    [ "${BOARD_LOCAL_API_KEY}"      = "lkey" ]
    [ "${BOARD_READ_WRITE_KEY}"     = "rwkey" ]
    [ "${WEATHER_PROVIDER}"         = "openweathermap" ]
    [ "${WEATHER_API_KEY}"          = "wkey" ]
    [ "${WEATHER_LOCATION}"         = "San Francisco, CA" ]
    [ "${TIMEZONE}"                 = "America/Los_Angeles" ]
    [ "${FIESTABOARD_EXTERNAL_URL}" = "http://ha.local:4420" ]
    [ "${LOG_LEVEL}"                = "debug" ]
    [ "${MQTT_ENABLED}"             = "true" ]
}

@test "apply_options skips empty options" {
    cat > "${HA_RUN_OPTIONS_FILE}" <<'JSON'
{
  "board_api_mode": "local",
  "board_host": "",
  "weather_api_key": "wkey"
}
JSON
    apply_options
    [ "${BOARD_API_MODE}" = "local" ]
    [ "${WEATHER_API_KEY}" = "wkey" ]
    [ -z "${BOARD_HOST:-}" ]
}

@test "apply_options handles missing options file gracefully" {
    rm -f "${HA_RUN_OPTIONS_FILE}"
    run apply_options
    [ "$status" -eq 0 ]
    [ -z "${BOARD_API_MODE:-}" ]
}

@test "apply_options exports MQTT_ENABLED=false explicitly when disabled" {
    cat > "${HA_RUN_OPTIONS_FILE}" <<'JSON'
{ "mqtt_enabled": false }
JSON
    apply_options
    [ "${MQTT_ENABLED:-}" = "false" ]
}

# ---------------------------------------------------------------------------
# configure_mqtt — supervisor service binding
# ---------------------------------------------------------------------------

start_fake_supervisor() {
    # Tiny Python http.server that returns the canned MQTT service payload.
    local port_file="${TMP}/sup.port"
    python3 - "${port_file}" <<'PY' &
import http.server, json, socket, sys, threading

PAYLOAD = {
    "result": "ok",
    "data": {
        "host": "core-mosquitto",
        "port": 1883,
        "username": "addons",
        "password": "secret",
        "ssl": False,
        "protocol": "3.1.1"
    }
}

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/services/mqtt":
            self.send_response(404); self.end_headers(); return
        if self.headers.get("Authorization") != "Bearer test-token":
            self.send_response(401); self.end_headers(); return
        body = json.dumps(PAYLOAD).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a, **kw): pass

s = http.server.HTTPServer(("127.0.0.1", 0), H)
with open(sys.argv[1], "w") as f:
    f.write(str(s.server_address[1]))
s.serve_forever()
PY
    SUPERVISOR_PID=$!
    # Wait for port file
    for _ in $(seq 1 50); do
        [ -s "${port_file}" ] && break
        sleep 0.05
    done
    local port
    port="$(cat "${port_file}")"
    export HA_RUN_SUPERVISOR_URL="http://127.0.0.1:${port}"
}

@test "configure_mqtt skips when MQTT_ENABLED=false" {
    export MQTT_ENABLED=false
    export SUPERVISOR_TOKEN=test-token
    configure_mqtt
    [ -z "${MQTT_BROKER_HOST:-}" ]
}

@test "configure_mqtt skips when no SUPERVISOR_TOKEN" {
    unset SUPERVISOR_TOKEN
    configure_mqtt
    [ -z "${MQTT_BROKER_HOST:-}" ]
}

@test "configure_mqtt populates MQTT_* from supervisor response" {
    start_fake_supervisor
    export SUPERVISOR_TOKEN=test-token
    configure_mqtt
    [ "${MQTT_ENABLED:-}"     = "true" ]
    [ "${MQTT_BROKER_HOST:-}" = "core-mosquitto" ]
    [ "${MQTT_BROKER_PORT:-}" = "1883" ]
    [ "${MQTT_USERNAME:-}"    = "addons" ]
    [ "${MQTT_PASSWORD:-}"    = "secret" ]
}

@test "configure_mqtt leaves env unset when supervisor unreachable" {
    export HA_RUN_SUPERVISOR_URL="http://127.0.0.1:1"  # nothing listening
    export SUPERVISOR_TOKEN=test-token
    configure_mqtt
    [ -z "${MQTT_BROKER_HOST:-}" ]
}

# ---------------------------------------------------------------------------
# configure_home_assistant_api
# ---------------------------------------------------------------------------

@test "configure_home_assistant_api wires defaults from SUPERVISOR_TOKEN" {
    export SUPERVISOR_TOKEN=ha-token
    export HA_RUN_SUPERVISOR_URL="http://supervisor"
    configure_home_assistant_api
    [ "${HOME_ASSISTANT_BASE_URL:-}"     = "http://supervisor/core" ]
    [ "${HOME_ASSISTANT_ACCESS_TOKEN:-}" = "ha-token" ]
}

@test "configure_home_assistant_api respects user-provided values" {
    export SUPERVISOR_TOKEN=ha-token
    export HOME_ASSISTANT_BASE_URL="http://my-ha:8123"
    export HOME_ASSISTANT_ACCESS_TOKEN="my-llat"
    configure_home_assistant_api
    [ "${HOME_ASSISTANT_BASE_URL}"     = "http://my-ha:8123" ]
    [ "${HOME_ASSISTANT_ACCESS_TOKEN}" = "my-llat" ]
}

@test "configure_home_assistant_api is a no-op without SUPERVISOR_TOKEN" {
    unset SUPERVISOR_TOKEN
    configure_home_assistant_api
    [ -z "${HOME_ASSISTANT_BASE_URL:-}" ]
    [ -z "${HOME_ASSISTANT_ACCESS_TOKEN:-}" ]
}

# ---------------------------------------------------------------------------
# main — exec hand-off
# ---------------------------------------------------------------------------

@test "main exec's the upstream entrypoint with supplied args" {
    # Drive the script as a subprocess with a stub command that records argv.
    local stub="${TMP}/stub.sh"
    local recorded="${TMP}/recorded"
    cat > "${stub}" <<EOF
#!/usr/bin/env bash
echo "ARGS: \$*" > "${recorded}"
EOF
    chmod +x "${stub}"

    HA_RUN_OPTIONS_FILE="${HA_RUN_OPTIONS_FILE}" \
    HA_RUN_DATA_DIR="${HA_RUN_DATA_DIR}" \
    HA_RUN_APP_DATA_DIR="${HA_RUN_APP_DATA_DIR}" \
    HA_RUN_SUPERVISOR_URL="${HA_RUN_SUPERVISOR_URL}" \
        bash "${SCRIPT}" "${stub}" hello world

    [ -f "${recorded}" ]
    grep -q "ARGS: hello world" "${recorded}"
}
