# Changelog

All notable changes to the FiestaBoard Home Assistant App will be documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 — Unreleased

### Added

- Initial release: wraps the upstream `fiestaboard/fiestaboard:5.6.0` image as a
  Home Assistant Supervisor add-on (a.k.a. "app").
- Supervisor Ingress: FiestaBoard appears in the Home Assistant sidebar with
  one-click web access and HA-managed authentication.
- Direct LAN port: container port 3000 is also exposed on host port 4420 so
  other devices on the network can reach FiestaBoard via mDNS or its IP.
- Auto MQTT discovery: when the Mosquitto add-on is installed, FiestaBoard
  picks up its broker host/credentials automatically through the Supervisor
  services API. No manual broker config required.
- Home Assistant core API: `homeassistant_api: true` lets FiestaBoard's
  built-in `home_assistant` plugin talk to HA via the Supervisor proxy.
- Curated configuration schema in HA's add-on Options UI: board mode/host/keys,
  weather provider/key/location, timezone, MQTT toggle, external URL, log level.
  All other FiestaBoard settings remain available in FiestaBoard's own web UI.
- Persistent data: FiestaBoard's `/app/data` is symlinked to HA's `/data`
  volume so settings, plugin state, and external plugins are captured by HA's
  built-in backup mechanism automatically.
- Supported architectures: `aarch64`, `amd64`.
