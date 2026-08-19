# Moonvibe backlog

Work top to bottom. Phases from [docs/PRODUCT.md](docs/PRODUCT.md) §6.

## P0 — Fork & foundation
- [x] Import moonlight-qt master (full history, 5 submodules)
- [x] Rebrand: app ID `io.github.dexterlabs1.Moonvibe`, binary `moonvibe`, icon, desktop/appdata, version 0.1.0
- [x] Flatpak manifest (`packaging/flatpak/`) with gamescope-WSI layer + Deck finish-args
- [x] CI: AppImage + Flatpak bundle on every push
- [ ] First on-Deck smoke test of the Flatpak artifact (HDR under gamescope, pairing, stream)
- [ ] Make repo public + tag v0.1.0 release with both artifacts

## P1 — Deck-first UI shell
- [ ] New QML shell: home/library per mockups (hero row, capsule grid, footer glyph hints)
- [ ] 100% controller-complete navigation (audit every dialog; single spatial-nav system)
- [ ] Pairing wizard: discovery → OTP/PIN pad (no OS keyboard) → bandwidth probe → defaults
- [ ] Per-host → per-app settings inheritance (origin tags in UI)
- [ ] SteamGridDB artwork enrichment with `appasset` fallback + cache
- [ ] "Add to Steam" button (shortcut + artwork + controller profile, chiaki-ng style)

## P2 — In-stream control
- [ ] In-stream drawer (Select+L5, configurable): client-side settings, stats tiers, hold-to-quit ring
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
