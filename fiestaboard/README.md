# FiestaBoard

> ⚠️ **Beta.** This add-on works end-to-end but its integration with HA Supervisor is still maturing. Please [report issues](https://github.com/Fiestaboard/FiestaBoard-Home-Assistant-App/issues) so we can iron them out.

[FiestaBoard](https://fiestaboard.app) is an open-source self-hosted platform
for controlling Vestaboard split-flap displays. Connect your Vestaboard
Flagship (22×6) or Note (15×3), then use built-in plugins to display weather,
stocks, sports, transit, surf, calendars, and more.

This add-on packages FiestaBoard for the Home Assistant Supervisor.

## Features

- One-click **Open Web UI** in the add-on page (LAN port `4420`).
- Auto MQTT discovery — works zero-config with the official Mosquitto add-on.
- Talks to Home Assistant core via the Supervisor proxy (no token needed).
- All settings persisted in `/app/data` (HA `addon_config` volume) and captured by HA backups.
- mDNS / `.local` URLs supported on the same port (e.g. `http://homeassistant.local:4420`).

See the **Documentation** tab for setup details and the
[upstream README](https://github.com/Fiestaboard/FiestaBoard) for plugin docs.
