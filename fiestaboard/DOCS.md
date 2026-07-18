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
| `fiestaboard_external_url` | string | URL shown as the "Visit" link on FiestaBoard's MQTT device page in HA. Leave blank to omit the link. |
| `fiestaboard_auth_enabled` | bool | FiestaBoard 6.0+ in-app login. Defaults **off** because HA Ingress already authenticates web access. Turn this on if you publish the LAN port (`4420`) to the internet. |
| `fiestaboard_session_ttl_seconds` | int | Session lifetime when `fiestaboard_auth_enabled` is on. `0` means use upstream's default (7 days). |
| `fiestaboard_mcp_token` | password | Pre-shared bearer token for FiestaBoard's `/mcp` endpoint (Claude Desktop / Claude Code). Only relevant when in-app auth is on. |
| `log_level` | enum | One of `debug`, `info`, `warning`, `error`. |

## Network access

FiestaBoard is reachable in three ways:

1. **Ingress** (recommended) — click **Open Web UI** in the add-on page or
   the sidebar entry. No port exposure required; HA's auth wrapper gates
   access.
2. **Host port `4420`** — `http://<your-ha-host>:4420`. Useful for browsers
   on the same network and for the FiestaBoard mobile experience.
3. **mDNS** — if your network supports `.local` resolution, FiestaBoard
   advertises itself; try `http://homeassistant.local:4420`.

### How the sidebar embed works

The FiestaBoard UI is a Next.js app with build-time-static `assetPrefix`,
while HA Ingress signals a per-installation URL prefix via the
`X-Ingress-Path` header. Three upstream PRs make the two compose:

- [Fiestaboard/FiestaBoard#913](https://github.com/Fiestaboard/FiestaBoard/pull/913) —
  nginx `sub_filter` rewrites `/_next/` and `/api/` URLs in HTML responses
  so the initial wave of script/stylesheet tags loads through Ingress.
- [Fiestaboard/FiestaBoard#914](https://github.com/Fiestaboard/FiestaBoard/pull/914) —
  extends the rewriting to CSS bodies and unquoted `url(/_next/...)` so
  fonts referenced from stylesheets resolve correctly too.
- [Fiestaboard/FiestaBoard#915](https://github.com/Fiestaboard/FiestaBoard/pull/915) —
  injects a runtime URL-patching `<script>` as the first child of `<head>`
  that patches Next.js's client-runtime URL construction
  (`HTMLLinkElement.prototype.href` setter, `setAttribute`, `fetch`,
  XHR), so the font preloads `ReactDOM.preload` emits during hydration —
  which bypass everything `sub_filter` can reach — also honor the prefix.

All three only fire when `FIESTABOARD_INGRESS_PATH_REWRITE=true` (which
the HA add-on sets unconditionally because the add-on is always behind
Ingress). For standalone Docker deployments the env var stays off and the
upstream image's behavior is unchanged.

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

1. **Home Assistant Ingress already authenticates** — the "Open Web UI"
   path from the sidebar is gated by HA's own login.
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
