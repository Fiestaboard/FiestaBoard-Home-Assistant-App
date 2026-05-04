# FiestaBoard Home Assistant App — Setup

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
| `log_level` | enum | One of `debug`, `info`, `warning`, `error`. |

## Network access

FiestaBoard is reachable in three ways:

1. **Ingress** (recommended) — click **Open Web UI** in the add-on page or the
   sidebar entry. No port exposure required.
2. **Host port `4420`** — `http://<your-ha-host>:4420`. Convenient for browsers
   on the same network and for the FiestaBoard mobile experience.
3. **mDNS** — if your network supports `.local` resolution, FiestaBoard
   advertises itself; try `http://homeassistant.local:4420`.

## MQTT auto-discovery

If the official **Mosquitto broker** add-on is installed (or any other broker
exposed to HA via the `mqtt` service), FiestaBoard picks up the broker host
and credentials automatically. You'll see FiestaBoard show up as a device in
**Settings → Devices & Services → MQTT** with no manual config.

To turn it off, set `mqtt_enabled: false` in Configuration.

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

To pull in a new upstream FiestaBoard release, this add-on must be rebuilt
against the new base image. Watch the
[releases](https://github.com/Fiestaboard/FiestaBoard-Home-Assistant-App/releases)
page; updating works through the normal HA add-on update flow.

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
