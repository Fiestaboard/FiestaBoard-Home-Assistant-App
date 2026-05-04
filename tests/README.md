# Tests

Unit tests for the FiestaBoard Home Assistant app's runtime shim.

## Layout

- `ha-run.bats` — Bats tests covering [`fiestaboard/rootfs/usr/local/bin/ha-run.sh`](../fiestaboard/rootfs/usr/local/bin/ha-run.sh):
  - `link_data_dir` — `/app/data → /data` symlink behavior (creation, idempotency, migration).
  - `apply_options` — mapping `/data/options.json` to `BOARD_*` / `WEATHER_*` / `TIMEZONE` / `MQTT_ENABLED` / `LOG_LEVEL` / etc. environment variables.
  - `configure_mqtt` — auto-discovery of the Supervisor-provided MQTT broker via `${HA_RUN_SUPERVISOR_URL}/services/mqtt` (uses an in-process Python `http.server` fixture).
  - `configure_home_assistant_api` — wiring `HOME_ASSISTANT_BASE_URL` / `HOME_ASSISTANT_ACCESS_TOKEN` from the Supervisor API token.
  - `main` — verifies the shim `exec`'s the upstream entrypoint with the supplied argv.

The shim supports a test-only hook: when sourced with `HA_RUN_SOURCE_ONLY=1` it loads its functions without invoking `main`, which lets each test drive a single function in isolation.

## Running locally

Prereqs: `bats`, `jq`, `python3`, `shellcheck` (for the lint step). On macOS:

```sh
brew install bats-core jq shellcheck
```

Then from the repo root:

```sh
bats tests/
```

To run a single test file:

```sh
bats tests/ha-run.bats
```

## CI

These tests run automatically on every push and pull request via [`.github/workflows/test.yaml`](../.github/workflows/test.yaml), alongside a Docker buildx smoke test that builds the wrapper image for `linux/amd64` and probes `/api/health`.
