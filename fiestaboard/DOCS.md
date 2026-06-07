# FiestaBoard Home Assistant App — Setup

> ⚠️ **Beta.** End-to-end install works (Ingress, MQTT auto-discovery, HA core API, backups, updates through the add-on store) but the wrapper is still maturing — please file issues at
> <https://github.com/Fiestaboard/FiestaBoard-Home-Assistant-App/issues> if anything surprises you.

## Requirements

This add-on installs through the Home Assistant **Add-on Store**, which is only
available on:

- **Home Assistant OS** (the all-in-one image)
- **Home Assistant Supervised** (Supervisor running on Debian)

If you run **Home Assistant Container** or **Home Assistant Core**, you don't
have the add-on infrastructure — use [FiestaBoard's Docker Compose
install](https://fiestaboard.app/docs/setup/quick-start) directly instead.

## Quick start

1. **Install the add-on** from the Add-on Store (this repository).
2. Open the **Configuration** tab and set, at minimum:
   - `board_api_mode`: `local` (recommended) or `cloud`.
   - For local mode: `board_host` (your board's IP, e.g. `192.168.1.50`) and
     `board_local_api_key` (request one at <https://www.vestaboard.com/local-api>).
   - For cloud mode: `board_read_write_key` from <https://web.vestaboard.com>.
   - `weather_api_key` from <https://www.weatherapi.com> (free tier works).
   - `weather_location` (e.g. `San Francisco, CA`).
   - `timezone` (e.g. `America/Los_Angeles`).
3. **Start** the add-on and click **Open Web UI** when it goes green.

The remaining FiestaBoard plugins (transit, sports, surf, AI art, etc.) are
configured from inside FiestaBoard's web UI — the Add-on Configuration tab
intentionally only surfaces the bootstrap-critical fields.

## Configuration reference

| Option | Type | Description |
| --- | --- | --- |
| `board_api_mode` | `local` \| `cloud` | Which Vestaboard API to use. Local is faster and supports transitions; cloud works from anywhere. |
| `board_host` | string | IP or hostname of your board (local mode only). |
| `board_local_api_key` | password | Local API key. |
| `board_read_write_key` | password | Cloud Read/Write key. |
| `weather_provider` | `weatherapi` \| `openweathermap` | Weather data source. |
| `weather_api_key` | password | API key for the chosen weather provider. |
| `weather_location` | string | Free-text location (e.g. city name). |
| `timezone` | string | IANA timezone (e.g. `America/Los_Angeles`). |
| `mqtt_enabled` | bool | Enable MQTT integration (auto-wired to HA's broker if installed). |
| `fiestaboard_external_url` | url | URL shown as the "Visit" link on FiestaBoard's MQTT device page in HA. |
| `fiestaboard_auth_enabled` | bool | FiestaBoard 6.0+ in-app login. Defaults **off** to keep the LAN port (`4420`) reachable without an extra login on a trusted network. Turn this on if you publish port `4420` to the internet — this add-on is no longer behind HA's Ingress auth wrapper as of 6.16.2-ha.2. |
| `fiestaboard_session_ttl_seconds` | int | Session lifetime when `fiestaboard_auth_enabled` is on. `0` means use upstream's default (7 days). |
| `fiestaboard_mcp_token` | password | Pre-shared bearer token for FiestaBoard's `/mcp` endpoint (Claude Desktop / Claude Code). Only relevant when in-app auth is on. |
| `log_level` | enum | One of `debug`, `info`, `warning`, `error`. |

## Network access

FiestaBoard is reachable on the LAN at port `4420`:

1. **"Open Web UI" button** — on the add-on page in HA. Opens
   `http://<your-ha-host>:4420` in a new tab.
2. **mDNS** — if your network supports `.local` resolution, try
   `http://homeassistant.local:4420`.
3. **Sidebar shortcut (optional)** — add a `panel_iframe:` entry in your
   HA `configuration.yaml` if you want a sidebar link:

   ```yaml
   panel_iframe:
     fiestaboard:
       title: FiestaBoard
       icon: mdi:billboard
       url: http://homeassistant.local:4420
       require_admin: false
   ```

### Why not HA Supervisor Ingress?

Earlier 6.16.x-ha.N releases exposed the panel via HA Ingress. Ingress
mounts the add-on under a per-installation URL prefix
(`/api/hassio_ingress/<token>/…`) signaled via the `X-Ingress-Path`
header. FiestaBoard is a Next.js app, and Next.js's client runtime
constructs dynamic asset URLs (font preloads emitted by
`ReactDOM.preload` during hydration, lazy chunks past navigation, etc.)
from a *build-time* `assetPrefix` that is empty in our build. Server-side
HTML/CSS rewriting (Fiestaboard/FiestaBoard#913 + #914) got the initial
wave through Ingress correctly, but everything the client computed
afterwards still hit the bare `/_next/...` origin root, 404'd against HA
core, and the sidebar iframe rendered with broken typography and missing
lazy assets. The mismatch is architectural — Next.js's `assetPrefix` is
build-time-static, HA Ingress's prefix is per-installation-dynamic, and
they don't compose without an upstream Next.js change we don't yet have.
LAN-port access sidesteps the whole problem.

## MQTT auto-discovery

If the official **Mosquitto broker** add-on is installed (or any other broker
exposed to HA via the `mqtt` service), FiestaBoard picks up the broker host
and credentials automatically. You'll see FiestaBoard show up as a device in
**Settings → Devices & Services → MQTT** with no manual config.

To turn it off, set `mqtt_enabled: false` in Configuration.

## Authentication (FiestaBoard 6.0+)

Upstream FiestaBoard 6.0 introduced a secure-by-default login. This add-on
ships with `fiestaboard_auth_enabled: false`, which keeps the previous
behavior: anyone who reaches the FiestaBoard UI can use it. That's the right
default for two reasons:

1. **Trusted-LAN deployment is the common case** — the LAN port (`4420`)
   is only reachable inside your network unless you explicitly publish it,
   and most users keep it private.
2. **Webhook callers (HA automations, scripts) keep working** — `POST
   /api/plugins/{plugin_id}/receive` would otherwise return `401`.

Turn `fiestaboard_auth_enabled` on if you expose host port `4420` to the
internet or share it with people you don't want to give HA logins to. When
auth is on:

- The first visit shows a setup picker; pick a username/password.
- Service-to-service callers (Claude Desktop's MCP client, CI webhooks)
  authenticate with `fiestaboard_mcp_token` instead of a cookie. Generate one
  with `python -c "import secrets; print(secrets.token_urlsafe(32))"`.
- FiestaBoard auto-generates a Fernet secret key at `/app/data/.secret_key`
  for at-rest encryption. **Don't delete it** — losing it makes any
  encrypted secrets unrecoverable. HA's backups capture it automatically.

## Home Assistant integration

`homeassistant_api: true` is granted, which means FiestaBoard's
`home_assistant` plugin can read entity states (doors, garage, sensors, etc.)
through the Supervisor proxy without you creating a long-lived access token.
Configure which entities to display from FiestaBoard's web UI under
**Plugins → Home Assistant**.

## Persistent data and backups

The add-on stores all settings, plugin state, and installed marketplace
plugins in FiestaBoard's `/app/data` directory. Home Assistant Supervisor
mounts this directly from its persistent `addon_config` volume (see `map`
in `config.yaml`), which means **HA's built-in backup captures everything**
— when you restore a snapshot, FiestaBoard comes back exactly as it was.

`/app/data/settings.json` is the canonical FiestaBoard config file. You can
hand-edit it via the **Files** add-on (path: `/addon_configs/<slug>/settings.json`)
or over SSH if needed.

## Updating

Updates come through the **Home Assistant add-on store** like any other
add-on. A weekly workflow in this repo polls upstream FiestaBoard for new
releases and opens a sync PR; once merged and tagged, HA Supervisor offers
the update to you.

FiestaBoard's own in-app "Update Now" button is **intentionally hidden**
under HA. Upstream ships a companion sidecar container (`fiestaupdater`)
that updates a standalone Docker install in place via the host docker
socket — that mechanism would race HA Supervisor's own update flow and
isn't safe to run inside an add-on. The shim disables it so the only
update path is through HA's UI.

## Troubleshooting

- **"Open Web UI" times out**: check the **Log** tab for errors. The first
  start can take 30–60s while supervisord boots the API, Next.js, and nginx.
- **MQTT not discovered**: ensure the Mosquitto add-on is **started** before
  starting FiestaBoard, and that `mqtt_enabled: true` in Configuration.
- **Board not responding (local mode)**: confirm the board is on the same
  network and `board_host` is reachable from the HA host. The logs include
  the exact failing URL.

## Support

- Issues: <https://github.com/Fiestaboard/FiestaBoard-Home-Assistant-App/issues>
- Discord: <https://discord.gg/ujasGntNhQ>
- Docs: <https://fiestaboard.app>
