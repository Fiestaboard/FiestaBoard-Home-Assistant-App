# Changelog

All notable changes to the FiestaBoard Home Assistant App will be documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 6.16.1-ha.1 — 2026-06-07

### Changed

- Bumped upstream FiestaBoard from **6.16.0 → 6.16.1**. 6.16.1 ships
  upstream [#913](https://github.com/Fiestaboard/FiestaBoard/pull/913),
  which makes nginx honor the `X-Ingress-Path` header that HA Supervisor
  sends on every proxied request. The add-on now exports
  `FIESTABOARD_INGRESS_PATH_REWRITE=true` so the upstream snippet
  rewrites absolute `/_next/` and `/api/` paths in HTML to include the
  Ingress URL prefix. Without this, the browser resolved Next.js chunk
  URLs against HA's origin root, bypassed Ingress, 404'd, and the
  sidebar iframe showed "Refused to execute … nosniff" errors with a
  broken UI even though framing was now allowed.
- Switched the add-on versioning scheme to mirror the upstream
  FiestaBoard release (`<upstream>-ha.N`). The hourly upstream-bump
  workflow uses this scheme; this release locks it in.

## 0.2.2 — 2026-06-07

### Changed

- Bumped upstream FiestaBoard from **6.14.0 → 6.16.0**. 6.16.0 makes nginx's
  frame-embedding headers configurable via env (upstream
  [#909](https://github.com/Fiestaboard/FiestaBoard/pull/909)); the add-on
  now sets `FIESTABOARD_X_FRAME_OPTIONS=OFF` and
  `FIESTABOARD_FRAME_ANCESTORS='self'` so the FiestaBoard UI renders inside
  the Home Assistant sidebar iframe. Previously the panel loaded fine in a
  fresh tab but the sidebar entry was blank because the default
  `X-Frame-Options: SAMEORIGIN` denied framing under HA Ingress's sandboxed
  iframe.
- Hide FiestaBoard's in-app "Update Now" affordance. Updates flow exclusively
  through the Home Assistant add-on store; the upstream sidecar updater is
  not safe to run alongside HA Supervisor's own update mechanism.

## 0.2.0 — 2026-06-06

### Changed

- Bumped upstream FiestaBoard from **5.6.0 → 6.14.0**. 6.0.0 added a
  secure-by-default login layer; the add-on now sets
  `FIESTABOARD_AUTH_ENABLED=false` by default so Home Assistant's Ingress and
  the LAN port stay reachable without an extra in-app login. Flip the new
  `fiestaboard_auth_enabled` option to `true` if you want FiestaBoard's own
  username/password gate (recommended if you publish the LAN port to the
  internet).
- The MCP bearer token (`fiestaboard_mcp_token`) is now exposable as an
  add-on option for service-to-service callers (Claude Desktop, etc.) when
  auth is on.

### Added

- New options: `fiestaboard_auth_enabled`, `fiestaboard_session_ttl_seconds`,
  `fiestaboard_mcp_token`. All translate directly to upstream env vars; see
  DOCS.md for guidance.
- Weekly **upstream-bump** workflow (`.github/workflows/upstream-bump.yaml`):
  polls Docker Hub for new `fiestaboard/fiestaboard` tags and opens a PR
  updating `build.yaml` + `Dockerfile`. Replaces the previous Dependabot
  docker watch, which never fired because it parses Dockerfile pins but the
  real per-arch pin lives in `build.yaml`.

## 0.1.0 — 2026-05-04

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
- Persistent data: FiestaBoard's `/app/data` is mounted directly from HA's
  `addon_config` volume so settings, plugin state, and external plugins are
  captured by HA's built-in backup mechanism automatically.
- Supported architectures: `aarch64`, `amd64`.
