# FiestaBoard Home Assistant App Repository

[![Open your Home Assistant instance and show the app store with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_store.svg)](https://my.home-assistant.io/redirect/supervisor_store/?repository_url=https%3A%2F%2Fgithub.com%2FFiestaboard%2FFiestaBoard-Home-Assistant-App)

This repository packages [FiestaBoard](https://fiestaboard.app) — the open-source self-hosted platform for controlling Vestaboard split-flap displays — as a Home Assistant Supervisor add-on (a.k.a. "app").

Install it from your Home Assistant Supervisor and FiestaBoard appears in the sidebar with one-click ingress, automatic MQTT discovery, and Home Assistant–managed backups of all your settings.

## Apps

### [FiestaBoard](./fiestaboard)

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

Run FiestaBoard inside Home Assistant. Connect your Vestaboard, configure plugins (weather, transit, sports scores, MQTT, and more), and control everything from the Home Assistant UI.

## Installation

1. In Home Assistant, navigate to **Settings → Add-ons → Add-on Store**.
2. Click the **⋮** menu (top-right) → **Repositories**.
3. Add this repository URL:
   `https://github.com/Fiestaboard/FiestaBoard-Home-Assistant-App`
4. The **FiestaBoard** add-on will appear in the store. Install, configure, and start.

Or click the badge above to add the repository in one click.

## Documentation

- FiestaBoard project: <https://fiestaboard.app>
- FiestaBoard source: <https://github.com/Fiestaboard/FiestaBoard>
- Home Assistant Apps developer docs: <https://developers.home-assistant.io/docs/apps>

## License

[MIT](./LICENSE)

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
