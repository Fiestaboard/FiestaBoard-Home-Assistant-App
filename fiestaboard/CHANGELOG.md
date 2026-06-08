# Changelog

All notable changes to the FiestaBoard Home Assistant App will be documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 6.17.2-ha.1 — 2026-06-07

### Changed

- Bumped upstream FiestaBoard from **6.17.1 → 6.17.2** to pick up
  [Fiestaboard/FiestaBoard#919](https://github.com/Fiestaboard/FiestaBoard/pull/919),
  which replaces Next.js with a Vite-built **React Router v7** SPA.
  Every asset URL (HTML `<link>`/`<script>` srcs, ES dynamic-`import()`
  chunk paths, CSS `url()` references) is now a string literal in the
  build output, so HA Ingress prefixing is a single nginx `sub_filter`
  pass over HTML / JS / CSS responses for `/assets/`, `/sw.js`,
  `/registerSW.js`, `/api/`, `/icons/`, `/manifest.json`, `/favicon.ico`.
- **The Ingress URL-prefix bug is properly fixed.** The four-PR chain
  we threaded through 6.16.1-ha.1 → 6.17.1-ha.1
  (#913 HTML sub_filter, #914 CSS sub_filter, #915 runtime URL-patching
  `<script>`, #918 patch-narrowed-to-`link.href`) was a moving target
  because Next.js's React-19-internal `ReactDOM.preload()` constructed
  asset URLs *after* hydration that no proxy-level rewrite or prototype
  patch could safely intercept without disturbing React internals. With
  the SPA migration there is no React-internal post-hydration URL
  construction to chase: `vite-plugin-pwa` replaces `next-pwa`, all
  asset references are emitted at build time, and the rewrite is
  exhaustive. The runtime `<script>` injection (#915/#918) is gone.
- **Sidebar Ingress stays on**, exactly as it was in 6.17.1-ha.1. The
  add-on's three exports (`FIESTABOARD_X_FRAME_OPTIONS=OFF`,
  `FIESTABOARD_FRAME_ANCESTORS='self'`,
  `FIESTABOARD_INGRESS_PATH_REWRITE=true`) are unchanged — same env
  variables, simpler implementation behind them. No `ha-run.sh` logic
  changes (only stale-comment refreshes).
- One-time service-worker cleanup: the upstream SPA's
  `entry.client.tsx` ships a kill-switch that unregisters pre-cutover
  `next-pwa` service workers and clears their caches on first boot
  post-cutover, then reloads. Users upgrading from any prior `-ha.N`
  will see one extra reload on the first sidebar open; subsequent
  boots are clean (no stale `/_next/*` cache).

### Image size

- Upstream dropped the Node 26 runtime tier (production now serves
  static files via nginx instead of running Next.js's Node server
  alongside it). The base image shrinks by ~150 MB and supervisord
  manages two processes (api + nginx) instead of three.

## 6.17.1-ha.1 — 2026-06-07

### Changed

- Bumped upstream FiestaBoard from **6.16.3 → 6.17.1** to pick up
  [Fiestaboard/FiestaBoard#918](https://github.com/Fiestaboard/FiestaBoard/pull/918).
  6.17.1 shrinks the runtime URL-patching script injected under HA
  Ingress to only override `HTMLLinkElement.prototype.href` — the React
  19 path `ReactDOM.preload` uses for `next/font` preloads, which was
  the originally-diagnosed bug.
- The previous version (6.16.3, shipped in 6.16.3-ha.1) also patched
  `Element.prototype.setAttribute`, `window.fetch`,
  `XMLHttpRequest.prototype.open`, and the script/img `src` setters.
  Live diagnostics in Safari on the user install showed React 19's
  hydration hung in a permanently-pending Suspense state
  (`<div hidden><!--$--><!--/$--></div>`) — React 19 calls `setAttribute`
  and `fetch` heavily during hydration, and replacing them with
  wrappers (even passthroughs) was enough to trip the reconciliation.
  Jsdom didn't surface this because its React-DOM implementation isn't
  real. The 6.17.1 patch is bit-for-bit identical to the platform for
  every API except `link.href`, so the React internals see native
  behavior everywhere they touch.
- No add-on-side changes besides the version bump — the
  `FIESTABOARD_INGRESS_PATH_REWRITE=true` export wired in 6.16.1-ha.1
  continues to apply.

### Trade-off documented

Dynamically-constructed URLs that don't pass through the link-href
setter (e.g. lazy chunk imports, fetch URLs to non-Ingress endpoints)
won't be rewritten by 6.17.1's narrower patch. In practice the
static-HTML sub_filter (#913) already covers the lazy chunk URLs
because they're declared as `<link rel="preload" as="script">` in the
initial response, and `ReactDOM.preload` font preloads — the
high-value case — go through `link.href`.

## 6.16.3-ha.1 — 2026-06-07

### Changed

- Bumped upstream FiestaBoard from **6.16.2 → 6.16.3** to pick up
  [Fiestaboard/FiestaBoard#915](https://github.com/Fiestaboard/FiestaBoard/pull/915),
  which injects a runtime URL-patching `<script>` as the first child of
  `<head>` when the request comes via HA Ingress. The script patches
  Next.js's client-runtime URL construction
  (`HTMLLinkElement.prototype.href` setter, `setAttribute`, `window.fetch`,
  `XMLHttpRequest.prototype.open`) so dynamic asset requests emitted
  after hydration (font preloads via `ReactDOM.preload`, lazy chunks)
  honor `X-Ingress-Path`. Without this patch Next.js's build-time-static
  `assetPrefix=""` produced bare `/_next/...` requests that 404'd against
  HA's origin root and broke typography in the sidebar iframe.
- **Restored `ingress: true` / `panel_icon` / `panel_title`.** The 6.16.2-ha.2
  release dropped Ingress and surfaced the panel via the LAN port because
  the sidebar iframe was unusable. With #915 in place, the embed works
  end-to-end (HTML, CSS, *and* dynamically-constructed asset URLs all go
  through Ingress correctly) so the sidebar entry is back.
- `ha-run.sh` re-exports `FIESTABOARD_X_FRAME_OPTIONS=OFF`,
  `FIESTABOARD_FRAME_ANCESTORS='self'`, and
  `FIESTABOARD_INGRESS_PATH_REWRITE=true` (it had stopped in 6.16.2-ha.2)
  so upstream's snippet + script-injection are active. Operators behind
  a non-HA reverse proxy can still override any of them by hand.
- LAN port (`4420`) stays open as a fallback / for direct mobile access
  on the local network. The panel itself now lives behind Ingress.

## 6.16.2-ha.2 — 2026-06-07

### Changed

- **Stopped using HA Supervisor Ingress for the FiestaBoard panel.** Upstream
  rewrites (Fiestaboard/FiestaBoard#913, #914) got the initial HTML/CSS
  through Ingress correctly, but Next.js's client runtime constructs
  dynamic asset URLs (font preloads, lazy chunks past navigation) from a
  *build-time* `assetPrefix` that's empty in our build. HA Ingress's URL
  prefix is *per-installation-dynamic*. Those two don't compose — the
  client kept fetching `/_next/static/media/…woff2` against HA's origin
  root and 404'ing, so the sidebar iframe rendered with no typography.
- The add-on now exposes itself via the LAN port (`4420`) instead. HA's
  add-on page surfaces an **Open Web UI** button (replacing the broken
  sidebar entry) that links to `http://<your-ha-host>:4420`. You can also
  reach FiestaBoard from any device on your LAN at that URL, or add a
  `panel_iframe:` entry in your HA `configuration.yaml` pointing to it if
  you want a sidebar shortcut.
- `ha-run.sh` no longer exports `FIESTABOARD_X_FRAME_OPTIONS=OFF`,
  `FIESTABOARD_FRAME_ANCESTORS='self'`, or
  `FIESTABOARD_INGRESS_PATH_REWRITE=true`. Direct LAN access doesn't need
  any of them, and the `sub_filter` snippet adds buffering overhead for no
  benefit when there is no proxy in front. Operators running their own
  reverse proxy can still set them by hand.

### Caveats

- The add-on is no longer behind HA's Ingress auth wrapper. If you expose
  port 4420 to the public internet, set `fiestaboard_auth_enabled: true`
  in add-on options so FiestaBoard's own login layer is active.

## 6.16.2-ha.1 — 2026-06-07

### Changed

- Bumped upstream FiestaBoard from **6.16.1 → 6.16.2**. 6.16.2 ships
  upstream [#914](https://github.com/Fiestaboard/FiestaBoard/pull/914),
  a follow-up to the 6.16.1 Ingress fix that also rewrites CSS bodies
  and unquoted `url(/_next/...)` references. Without it the sidebar
  iframe rendered with broken typography (`@font-face` URLs in the
  `text/css` response 404'd against HA's origin root), which looked
  like a near-blank dark screen plus two woff2 errors in the console.
  No add-on-side changes -- this picks up automatically because the
  `FIESTABOARD_INGRESS_PATH_REWRITE=true` export was already wired in
  6.16.1-ha.1.

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
