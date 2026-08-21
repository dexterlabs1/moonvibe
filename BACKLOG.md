# Moonvibe backlog

Work top to bottom. Phases from [docs/PRODUCT.md](docs/PRODUCT.md) §6.

## P0 — Fork & foundation
- [x] Import moonlight-qt master (full history, 5 submodules)
- [x] Rebrand: app ID `io.github.dexterlabs1.Moonvibe`, binary `moonvibe`, icon, desktop/appdata, version 0.1.0
- [x] Flatpak manifest (`packaging/flatpak/`) with gamescope-WSI layer + Deck finish-args
- [x] CI: AppImage + Flatpak bundle on every push
- [ ] First on-Deck smoke test of the Flatpak artifact (HDR under gamescope, pairing, stream)
- [x] Tag v0.1.0 release with both artifacts
- [ ] Make repo public (GPLv3 gate: required before distributing any build)

## P1 — Deck-first UI shell
- [x] Home screen replaces the host list as the entry point: cross-host recents, one adaptive primary action that absorbs wake/pair, library as a shelf
- [x] Dark theme shell v1 (v0.2.0): Theme singleton, wordmark top bar, footer controller-glyph hints, host status cards, app capsules with monogram placeholders + running badge, dark dialogs
- [x] New QML shell: home/library per mockups (Continue hero row of recently played apps above the capsule grid, footer glyph hints, focus moves between the two)
- [ ] 100% controller-complete navigation (audit every dialog; single spatial-nav system)
- [x] Settings rebuilt on the design system (SettingsSection, MvCheckBox/ComboBox/Slider/TextField); SteamGridDB field press-to-edit so the OSK cannot ambush
- [x] Rebindable in-stream shortcuts backend (KeyBindings, QSettings, QML API); defaults preserved bit-for-bit
- [ ] Shortcut-rebinding UI in Settings
- [ ] Pairing wizard: discovery → OTP/PIN pad (no OS keyboard) → bandwidth probe → defaults
  - [x] PIN step: host name, PIN in large tiles, deep link to the host web UI, waiting state
  - [ ] OTP pairing for Apollo/Vibepollo hosts
  - [ ] Bandwidth probe + recommended defaults steps
- [ ] Per-host → per-app settings inheritance (origin tags in UI)
- [x] SteamGridDB artwork enrichment with `appasset` fallback + cache (API key in Host Settings; unverified end to end -- no key available at build time)
- [ ] "Add to Steam" button (shortcut + artwork + controller profile, chiaki-ng style)

## P2 — In-stream control
- [ ] In-stream drawer (Select+L5, configurable): client-side settings, stats tiers, hold-to-quit ring
  - [x] Surface: StreamDrawer renders the panel into an SDL surface (software rasteriser + SDL_ttf, bundled fonts)
  - [x] Compositing: OverlayDrawer type + updateOverlaySurface(); positioned in SDL, EGL, Vulkan and DRM renderers
  - [x] Input: keys swallowed while open, arrows navigate/adjust, Escape closes
  - [x] Preview harness: MOONVIBE_DRAWER_PREVIEW=<path> renders it without a host or a stream
  - [ ] Verify over live video (blocked: this client lacks "Launch applications" permission on the host)
  - [x] Bind to Select+L5 (configurable gamepad chord; d-pad navigates, B closes)
  - [ ] Make the controls actually apply (bitrate needs the Vibepollo ABR path; res/HDR need soft reconnect)
- [ ] Trackpad radial quick actions
- [ ] Localhost WebSocket control API (session params, stats stream, end-session)
- [ ] Decky plugin v1: QAM panel with live stats, bitrate, end stream, host wake/sleep

## P3 — Vibepollo dialect
- [ ] ABR client implementation (Vibepollo ≥1.18 negotiation; live bitrate slider + auto mode)
- [ ] Soft reconnect for resolution/FPS/HDR changes (reuse pairing+control, restart RTSP/RTP only)
- [ ] Host capability badges; server commands; clipboard sync; virtual-display toggle; OTP pairing

## P4 — Deck-native deep cuts
- [ ] Raw-HID gyro → DS4 motion passthrough (chiaki-ng approach)
- [ ] Mic passthrough (Apollo streaming-microphone endpoint)
- [ ] Suspend/resume resilience + retry-forever auto-reconnect + WoL hardening
- [ ] 90 Hz OLED pacing polish (refresh-match prompts)

## P5 — Polish & publish
- [ ] One-paste installer (Flatpak + Steam shortcut + Decky plugin)
- [ ] Own flatpak repo + `.flatpakref`; Flathub submission; Decky store submission
- [ ] Docs site / setup guide

## Deferred / hardening (any time)
- [ ] Settings migration shim from `~/.config/Moonlight Game Streaming Project/`
- [ ] Mirror `cgutman/enet` + `cgutman/qmdnsengine` submodules (currently upstream personal forks)
- [ ] Translation (.ts) refresh for renamed strings (28 languages still say "Moonlight")
- [ ] Publish real `updates/qt.json` flow once releases exist (checker already points at it)
- [ ] Windows/macOS builds (explicitly out of scope until Deck experience is done)
