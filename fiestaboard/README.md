# FiestaBoard

[FiestaBoard](https://fiestaboard.app) is an open-source self-hosted platform
for controlling Vestaboard split-flap displays. Connect your Vestaboard
Flagship (22×6) or Note (15×3), then use built-in plugins to display weather,
stocks, sports, transit, surf, calendars, and more.

This add-on packages FiestaBoard for the Home Assistant Supervisor.

## Features

- Sidebar entry via Home Assistant Ingress.
- Auto MQTT discovery — works zero-config with the official Mosquitto add-on.
- Talks to Home Assistant core via the Supervisor proxy (no token needed).
- All settings persisted in `/data` and captured by HA backups.
- Direct LAN access on host port `4420` for mDNS / `.local` URLs.

See the **Documentation** tab for setup details and the
[upstream README](https://github.com/Fiestaboard/FiestaBoard) for plugin docs.
