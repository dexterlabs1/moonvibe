# Research: A Modern Moonlight Client for Steam Deck

*Compiled 2026-08-19 from four parallel web-research passes. This document is the
factual foundation for [PRODUCT.md](PRODUCT.md). All claims carry source links;
items we could not verify against a primary source are flagged inline.*

> **Note on repo placement:** this doc set lives in the Purple Meadows repo for
> convenience only. The client itself is a separate project and gets its own
> repository when implementation starts — nothing here touches the dome codebase.

---

## 1. The one-paragraph thesis

The niche "Vibepollo, but for the client side" is real and currently **vacant**.
moonlight-qt is alive but release-starved and feature-conservative; the
officially-blessed Deck-focused fork (Artemis Qt) went dormant in Aug 2025 with
its Steam Deck builds removed from CI; and in July 2026 **Vibepollo shipped the
host half of dynamic bitrate (ABR capability negotiation) that no mainstream
client consumes yet**. Every top-requested client feature already has proven
prior art scattered across Artemis, Vibelight, chiaki-ng, and StreamLight —
nobody has unified them in one maintained, Deck-first client.

---

## 2. Client ecosystem state (2025–2026)

### moonlight-qt (the canonical PC/Deck client)

- [moonlight-stream/moonlight-qt](https://github.com/moonlight-stream/moonlight-qt):
  C++ / Qt 6 QML UI / SDL2 input / FFmpeg decode / protocol via
  moonlight-common-c. GPL-3.0.
- Effectively single-maintainer (Cameron Gutman). Master is active (commits
  through Aug 2026) but the **last stable release is v6.1.0, Sep 2024** — users
  have been begging for a release for years
  ([#1711](https://github.com/moonlight-stream/moonlight-qt/issues/1711),
  [#1804](https://github.com/moonlight-stream/moonlight-qt/issues/1804)).
  ~509 open issues, 45 open PRs; community perception is "active code, absent
  releases, PRs rarely merged."
- Capability baseline already in v6.x
  ([releases](https://github.com/moonlight-stream/moonlight-qt/releases)):
  Vulkan renderer with **HDR on Steam Deck** (libplacebo), Vulkan Video decode
  (H.264/HEVC/AV1), E2E stream encryption (Sunshine ≥ 0.22), CLI-initiated
  streams with auto wake-on-LAN, experimental YUV 4:4:4, 500 Mbps ceiling,
  software-decode HDR.
- UI is desktop-mouse-oriented; gamepad nav is implemented by faking keyboard
  events ([sdlgamepadkeynavigation.cpp](https://github.com/moonlight-stream/moonlight-qt/blob/master/app/gui/sdlgamepadkeynavigation.cpp))
  and is incomplete (see §6).

### The Artemis lineage (the closest prior art)

- **Artemis Android** ([ClassicOldSong/moonlight-android](https://github.com/ClassicOldSong/moonlight-android),
  ~3.9k★, by the Apollo author): 30+ features over mainline — in-stream "Game
  menu" drawer, custom virtual buttons with import/export, five mouse modes,
  per-app custom resolutions/bitrates, fractional refresh, `art://` deep links,
  and Apollo-host features (virtual display control, server commands, clipboard
  sync, OTP pairing).
- **Artemis Qt** ([wjbeckett/artemis](https://github.com/wjbeckett/artemis),
  blessed with official Artemis branding in
  [Apollo #937](https://github.com/ClassicOldSong/Apollo/issues/937)): a
  moonlight-qt fork adding clipboard sync, server commands, OTP pairing, an
  **in-stream Quick Menu** (Ctrl+Alt+Shift+\ or Select+L1+R1+Y), client-side
  resolution scaling, virtual-display toggle, and "optimized UI for handhelds."
  **Dormant since ~Aug 2025 (last release 0.6.7-dev), Steam Deck builds removed
  from its CI.** This is exactly the vacancy our project fills.
- **Vibelight** ([xenstalker02/Vibelight](https://github.com/xenstalker02/Vibelight)):
  tiny Steam-Deck-only moonlight-qt fork adding **encrypted mic passthrough**
  (SDL2 capture → Opus 64 kbps mono → AES-GCM over the control stream) paired
  with its author's Vibepollo fork. Proof the mic feature is feasible
  client-side. Similar: [logabell/moonlight-qt-mic](https://github.com/logabell/moonlight-qt-mic).
- **StreamLight** ([FoggyBytes/StreamLight](https://github.com/FoggyBytes/StreamLight)):
  Windows-only moonlight-qt fork; gamepad-first UI with dynamic controller
  glyphs, **per-host profiles and per-game overrides**, seamless launch with
  cover art, and a host companion for remote unlock/metrics/power-off. Small,
  but validates the feature direction against Sunshine/Apollo/Vibepollo hosts.
- **qiin2333's moonlight-qt fork** ([repo](https://github.com/qiin2333/moonlight-qt)):
  proves the in-stream concept on desktop Qt — a floating in-stream menu with
  quick toggles (fullscreen, stats, mouse mode, mic, host file access),
  **configurable exit key combinations**, and an app view that shows which app
  is currently running on the host.

### Protocol libraries

- [moonlight-common-c](https://github.com/moonlight-stream/moonlight-common-c)
  (GPL-3.0) is the canonical, reusable C client implementation used by all
  official clients. It covers RTSP session negotiation, the ENet control
  stream, RTP video/audio depacketization, and Reed-Solomon FEC. Two gotchas:
  it **requires its bundled ABI-incompatible ENet fork** (IPv6 +
  retransmission changes), and the **HTTPS pairing / app-list layer is *not*
  included** — each client implements that itself (moonlight-qt's
  `NvHTTP`/`NvPairingManager`).
- There is **no official protocol spec** (NVIDIA never published one). The best
  written documentation is **Wolf's protocol write-up**
  ([games-on-whales.github.io/wolf](https://games-on-whales.github.io/wolf/stable/protocols/index.html)) —
  RTSP flow, control-stream packet formats, RTP layouts, FEC scheme.
  Otherwise moonlight-common-c source is the de-facto spec.
- Rust: [moonlight-common-rust](https://github.com/MrCreativ3001/moonlight-common-rust)
  is a young sans-IO implementation with optional C bindings; no
  production-quality full Rust client exists. **Practical takeaway: link
  moonlight-common-c, don't rewrite the protocol.**

### Protocol phases (per Wolf's docs)

1. **HTTPS 47984 / HTTP 47989** — pairing (cert exchange, PIN challenge),
   `serverinfo`, app list, launch/resume, and `appasset` box-art serving.
2. **RTSP 48010 (TCP)** — negotiates resolution, FPS, bitrate, codec, and the
   UDP stream parameters. **This is why most stream settings are
   fixed-per-session today.**
3. **Control stream (ENet over UDP 47999)** — input, rumble, IDR requests,
   reference-frame invalidation, termination; AES-encrypted.
4. **RTP video (UDP 47998) + Opus audio (UDP 48000)** — with Reed-Solomon FEC
   so the client repairs loss without retransmits.

---

## 3. Host lineage: Sunshine → Apollo → Vibepollo

- **Sunshine** (LizardByte) — the open-source GameStream host baseline. Aug 2026
  pre-releases are landing hardware YUV 4:4:4; AV1 encode requires RTX 40+/
  RDNA3+/Intel Arc ([docs](https://docs.lizardbyte.dev/projects/sunshine/v0.23.0/about/advanced_usage.html)).
- **Apollo** ([ClassicOldSong/Apollo](https://github.com/ClassicOldSong/Apollo),
  active, ~monthly releases): Sunshine fork adding the **SudoVDA virtual
  display** that auto-matches each client's resolution/refresh (each client
  gets a stable virtual-monitor identity so Windows remembers layouts),
  **per-client permission system**, clipboard sync, server commands
  (connect/disconnect automation), input-only mode, OTP pairing. Recommended
  client: Artemis. Merged a
  [Steam Streaming Microphone PR](https://github.com/ClassicOldSong/Apollo/pull/1428).
- **Vibepollo** ([Nonary/Vibepollo](https://github.com/Nonary/Vibepollo)) — the
  model we're emulating client-side: an ~99% AI-generated Apollo fork with a
  very fast release cadence. Adds:
  - Display-automation safeguards (virtual displays / dummy plugs never get
    "stuck" on return to desktop; Win11 24H2 fixes)
  - Frame-gen-aware capture (DLSS FG / FSR FG / Lossless Scaling / Smooth
    Motion frames actually captured), WGC service-mode capture
  - **RTSS + NVIDIA Control Panel integration** (auto frame limit + V-sync
    config per stream), Lossless Scaling automation
  - Virtual display running at 4× requested refresh with auto low-latency
    frame capping
  - Playnite library sync, v2 Web UI, native WebRTC browser streaming, AMD AMF
    AV1, **scoped API tokens** (a clean surface for a companion client/plugin),
    multi-client "Remote Monitor" sessions (Aug 2026 alpha)
  - **v1.18.0 (2026-07-11): "runtime bitrate adjustment and ABR capability
    negotiation for supported clients. NVENC changes bitrate without
    interrupting the stream; other encoders restart their encode session as
    needed"** ([release](https://github.com/Nonary/Vibepollo/releases/tag/v1.18.0)).
    No mainstream client implements the client side
    ([discussion #70](https://github.com/Nonary/Vibepollo/discussions/70)).

### Which client features need which host

| Feature | Needs |
|---|---|
| E2E encryption, HDR, gyro/motion passthrough (DS4 emu), host res-match commands | Sunshine ≥ 0.22 |
| Virtual display control, clipboard sync, server commands, OTP/`art://` pairing, per-client identity/permissions, fractional client FPS | Apollo / Vibepollo |
| **Live bitrate (ABR)** | **Vibepollo ≥ 1.18** |
| Mic passthrough | Apollo (merged PR) / Vibelight-pair forks — no upstream support ([moonlight-qt #1245](https://github.com/moonlight-stream/moonlight-qt/issues/1245)) |
| YUV 4:4:4 | experimental both sides; HEVC-only (no consumer AV1 4:4:4 encoder) |

### Mid-stream change taxonomy (what an in-stream drawer can actually do)

- **Free today, client-only, no protocol change:** scale mode, frame-pacing
  mode, stats overlay tiers, input/mouse modes, deadzones, mic mute, local
  cursor. (Artemis proved this class.)
- **Live with Vibepollo ≥ 1.18:** bitrate, via ABR negotiation (NVENC = truly
  seamless; other encoders = fast encoder restart + IDR resync).
- **Requires reconnect today:** resolution, FPS, HDR toggle (all negotiated at
  RTSP time; HDR also flips host display state). Opportunity: a **"soft
  reconnect"** that reuses pairing + control session and only restarts
  RTSP/RTP, hiding most of the latency behind a freeze-frame — nobody ships
  this yet (inference, not prior art).

---

## 4. Steam Deck platform facts

### Decode hardware — verified

- Van Gogh APU has **VCN 3.0** ([Phoronix / AMD kernel patches](https://www.phoronix.com/news/AMD-Van-Gogh-AMDGPU-Linux)):
  hardware decode for **H.264, HEVC Main+Main10 (HDR), and AV1 Profile 0
  (8/10-bit)**. No AV1 *encode* (irrelevant for a client). The OLED's Sephiroth
  APU is a die-shrink with identical decode.
- moonlight-qt can also decode all three codecs via **Vulkan Video** (v6.0+).
- Caveat: Mesa/SteamOS updates periodically break VCN paths (e.g. the July 2026
  AppImage AV1 breakage, [#1460](https://github.com/moonlight-stream/moonlight-qt/issues/1460)) —
  **ship a codec-fallback UX**, not just a codec picker.

### Display

- OLED: 90 Hz panel, user-adjustable ~45–90 Hz; **true HDR (~1000 nits) but
  only under gamescope/Gaming Mode**. LCD: 60 Hz (40–60), no HDR. **No VRR on
  either internal panel** (external displays only, via `--adaptive-sync`).
- Frame pacing: gamescope forces compositor vsync; a stream whose fps doesn't
  divide the panel refresh micro-stutters
  ([#795](https://github.com/moonlight-stream/moonlight-qt/issues/795),
  [#1191](https://github.com/moonlight-stream/moonlight-qt/issues/1191)).
  The OLED's adjustable refresh makes exact matching viable — and **90 fps
  streaming support is a differentiator** (Deck supports it; most clients
  default to 60).
- **Gamescope WSI trap:** the `ENABLE_GAMESCOPE_WSI` Vulkan layer is required
  for HDR/correct presentation, and a July 2026 SteamOS update made the
  Moonlight Flatpak crash on launch in Game Mode
  ([#1930](https://github.com/moonlight-stream/moonlight-qt/issues/1930), open
  at research time; workaround `ENABLE_GAMESCOPE_WSI=0` kills HDR). Any Vulkan
  client must test against SteamOS betas.
- Render at native 1280×800 to avoid a scaler pass.

### Input

- Under Gaming Mode any non-Steam app gets full **Steam Input** (virtual X360
  pad, trackpads, back buttons, community layouts) — but **Steam's virtual
  gamepad does not expose gyro to SDL**, so stock moonlight-qt can't forward
  Deck gyro ([#960](https://github.com/moonlight-stream/moonlight-qt/issues/960),
  [#1123](https://github.com/moonlight-stream/moonlight-qt/issues/1123)).
  **chiaki-ng solved this by reading the Deck's raw HID sensors directly** —
  a proven, copyable approach; Sunshine/Apollo can emulate a DS4 host-side to
  receive the motion data.
- The Deck has a dual-array mic; the stock stack has zero mic passthrough
  (see §3 for the forks that added it).
- Known Steam+X keyboard bug for non-Steam apps in Game Mode (desktop keyboard
  window or nothing; soft locks —
  [steam-for-linux #9117](https://github.com/ValveSoftware/steam-for-linux/issues/9117)):
  **never require free-text entry during onboarding; use D-pad PIN-pad
  widgets.**

### SteamOS / packaging

- Root fs is immutable, A/B-imaged, and **wiped on every OS update**; `/home`
  survives — so **Flatpaks, AppImages, and `~/homebrew` (Decky) persist**.
- Gaming Mode requires adding the app as a non-Steam shortcut; MoonDeck creates
  shortcuts programmatically via the injected `SteamClient` API and points them
  at its own runner script (recommended pattern).

---

## 5. Decky Loader — the Quick Access panel platform

- [Decky Loader](https://github.com/SteamDeckHomebrew/decky-loader) injects
  into Steam's CEF Gaming Mode UI. A plugin = React/TS frontend rendered in the
  Quick Access Menu (using [`@decky/ui`](https://github.com/SteamDeckHomebrew/decky-frontend-lib) —
  Valve's own styled components: `PanelSection`, `SliderField`, `ToggleField`,
  `Router`) + optional Python backend with full system access (spawn
  `flatpak run …`, open localhost sockets; `"root"` flag available but not
  needed here). Frontend↔backend bridge via `@decky/api`
  (`callable`, events, CORS-free fetch).
- **The QAM overlays a *running* Gaming Mode app** — adjusting an app mid-game
  from the panel is the normal pattern (PowerTools, SimpleDeckyTDP).
- **The gap we exploit:** stock moonlight-qt has **no runtime IPC** — all
  settings are fixed at process launch, which is why
  [MoonDeck](https://github.com/FrogTheFrog/moondeck) can only *relaunch*
  Moonlight with new CLI flags
  ([moonlightproxy.py](https://github.com/FrogTheFrog/moondeck/blob/main/defaults/python/lib/moonlightproxy.py)).
  A client with an embedded localhost WebSocket/HTTP control API gives the
  Decky plugin live mid-stream control — the thing no one has.
- [MoonDeck Buddy](https://github.com/FrogTheFrog/moondeck-buddy) (host-side Qt
  helper, HTTPS+JSON on :59999 with its own pairing) shows the host-companion
  pattern; Vibepollo's scoped API tokens may make a custom Buddy unnecessary.
- Distribution: official Decky store (PR to
  [decky-plugin-database](https://github.com/SteamDeckHomebrew/decky-plugin-database),
  human review), testing store (installable by anyone while the PR is open —
  a good friends-beta channel), or manual zip/URL install from Decky settings.
- Fragility: Decky patches Valve's minified React internals; plugins and Decky
  itself can break on Steam client updates.

---

## 6. Pain-point catalog (the "why" behind every feature)

### Most-demanded unshipped moonlight-qt features (👍 at research time)

| Ask | Issue | 👍 |
|---|---|---|
| Auto-switch host resolution to match client | [#784](https://github.com/moonlight-stream/moonlight-qt/issues/784) | 69 |
| Shared clipboard | [#1103](https://github.com/moonlight-stream/moonlight-qt/issues/1103) | 67 |
| Customizable hotkeys | [#1126](https://github.com/moonlight-stream/moonlight-qt/issues/1126) | 28 |
| Ship a release | [#1711](https://github.com/moonlight-stream/moonlight-qt/issues/1711)/[#1804](https://github.com/moonlight-stream/moonlight-qt/issues/1804) | 19/16 |
| Local-cursor modes (remote desktop) | [#1016](https://github.com/moonlight-stream/moonlight-qt/issues/1016)/[#1268](https://github.com/moonlight-stream/moonlight-qt/issues/1268) | 16/14 |
| Input-only mode | [#1146](https://github.com/moonlight-stream/moonlight-qt/issues/1146) | 13 |
| Save custom resolutions | [#834](https://github.com/moonlight-stream/moonlight-qt/issues/834) | 7 |
| Microphone streaming | [#1245](https://github.com/moonlight-stream/moonlight-qt/issues/1245) | 7 |
| Auto bitrate from connection quality | [#1618](https://github.com/moonlight-stream/moonlight-qt/issues/1618) | 7 |
| Auto-reconnect / retry forever | [#1379](https://github.com/moonlight-stream/moonlight-qt/issues/1379) | — |
| Gyro→DS4 on handhelds | [#1123](https://github.com/moonlight-stream/moonlight-qt/issues/1123) | — |
| Dynamic bitrate (closed "not planned"!) | [#802](https://github.com/moonlight-stream/moonlight-qt/issues/802) | — |

Most of these already exist in Artemis/Apollo — the demand and the host
plumbing both exist; the gap is a maintained Deck-first client.

### UI-specific complaints

- **Controller navigation dead ends:** pad works for most of the UI but "add a
  new machine" / dialog buttons need a mouse
  ([#1684](https://github.com/moonlight-stream/moonlight-qt/issues/1684));
  in-UI vs in-stream input layers fight each other
  ([PR #1145](https://github.com/moonlight-stream/moonlight-qt/pull/1145)).
- **Not a 10-foot/handheld UI:** open since 2020
  ([#466](https://github.com/moonlight-stream/moonlight-qt/issues/466));
  Deck scaling bugs ([#879](https://github.com/moonlight-stream/moonlight-qt/issues/879),
  [#946](https://github.com/moonlight-stream/moonlight-qt/issues/946)).
- **Single global settings page:** the most-duplicated request in the tracker —
  per-host ([#1187](https://github.com/moonlight-stream/moonlight-qt/issues/1187),
  [#1795](https://github.com/moonlight-stream/moonlight-qt/issues/1795)),
  named profiles ([#1327](https://github.com/moonlight-stream/moonlight-qt/issues/1327),
  [#213](https://github.com/moonlight-stream/moonlight-qt/issues/213)).
- **No in-stream settings; must quit to change anything**
  ([#1353](https://github.com/moonlight-stream/moonlight-qt/issues/1353);
  [android #1324](https://github.com/moonlight-stream/moonlight-android/issues/1324)).
- **Hardcoded quit chord** (Start+Select+L1+R1) collides with games
  ([#870](https://github.com/moonlight-stream/moonlight-qt/issues/870)) and
  sometimes misfires into the settings UI; devices without the buttons get
  stuck ([android #1227](https://github.com/moonlight-stream/moonlight-android/issues/1227)).
- **Pairing friction:** PIN must be typed into the host's web UI; on Deck this
  intersects the Steam+X keyboard bug (§4).
- **Box art gaps:** the protocol serves art via `appasset` (host `apps.json`
  `image-path` — [Sunshine NVHTTP](https://deepwiki.com/LizardByte/Sunshine/4.1-nvhttp-and-client-connection)),
  but hosts rarely configure it → blank tiles
  ([#346](https://github.com/moonlight-stream/moonlight-qt/issues/346)).
  Community routes around it with **SteamGridDB** tooling; the client should
  enrich art client-side (capsule 600×900, hero, logo) with `appasset` as
  fallback.
- Suspend kills streams; users want retry-forever
  ([#1379](https://github.com/moonlight-stream/moonlight-qt/issues/1379)); WoL
  works but is flaky (separate-MAC ask,
  [#1619](https://github.com/moonlight-stream/moonlight-qt/issues/1619)).
- MoonDeck's whole existence (launch any Steam game via Moonlight from the
  Deck library, QAM panel for host wake/restart) is evidence of the library
  and host-power-control gaps.

---

## 7. UI references worth stealing from

- **chiaki-ng** ([docs](https://streetpea.github.io/chiaki-ng/)) — the gold
  standard: ground-up controller-navigable QML UI, first-run wizard
  (discover → register → **"Add to Steam" button that ships artwork and a
  recommended controller profile**), per-console settings objects, native Deck
  gyro/haptics/touchscreen-as-touchpad, HDR on OLED, mic with noise
  suppression, and hard networking paths (remote via PSN) wrapped in wizards.
  Still actively improving (v1.10: congestion control, metrics).
- **Artemis / qiin2333 fork** — in-stream drawer + mode switchers +
  configurable quit chord + "currently running" surfaced in the grid (§2).
- **SteamOS itself** — the QAM slide-in panel is the canonical Deck in-stream
  drawer pattern; Steam Input
  [Touch Menus](https://partner.steamgames.com/doc/features/steam_controller/touch_menus)
  are the native radial-menu precedent (haptic tick per sector); persistent
  footer button-glyph hints; capsule grid + hero row conventions.
- **Parsec** ([overlay](https://support.parsec.app/hc/en-us/articles/32381603663636-Stream-Overlay-Stats-and-Logging)) —
  passive overlay icon with **proactive escalating warnings** ("network
  congestion → recommendation"), not just a stats wall. Its
  [BUD protocol](https://parsec.app/blog/a-networking-protocol-built-for-the-lowest-latency-interactive-game-streaming-1fd5a03a6007)
  (per-frame congestion feedback driving encoder bitrate) is the canonical ABR
  design reference.
- **GeForce NOW** — 0–4 bar corner network meter; pre-session network test.
- **Greenlight** (xCloud client) — trackpad-summoned overlay to
  end stream / mute mic.
- **MangoHud levels** — Deck users already know tiered stats (0 → corner bars →
  one-line → full breakdown); reuse the mental model.
- Cautionary tales: XBPlay (fonts too small on Deck), Kirigami/Bigscreen
  (immature for TV UIs), Flutter (no real gamepad story). **QML with
  SDL-driven spatial navigation applied to 100% of screens** (chiaki-ng
  proves it works; moonlight-qt proves piecemeal fails) is the evidenced path.

---

## 8. Verified-fact ledger / uncertainty flags

- AV1 decode on Van Gogh: **verified** (VCN 3.0; both Deck models identical).
- Vibepollo ABR: **verified** from the v1.18.0 release notes.
- Bitrate static-per-session in all stock clients; moonlight-qt closed dynamic
  bitrate as not-planned: **verified** ([#802](https://github.com/moonlight-stream/moonlight-qt/issues/802)).
- Artemis Qt dormancy: last release 0.6.7-dev (Aug 2025), develop branch quiet,
  Deck CI removed — **re-check before committing scope**; it could revive, in
  which case contributing there is an option.
- Gamescope WSI Flatpak crash ([#1930](https://github.com/moonlight-stream/moonlight-qt/issues/1930)):
  open at research time; may be fixed in a SteamOS point release — re-test.
- MoonDeck Buddy full endpoint list, Vibepollo star counts, moonlight-embedded
  last release: not fully enumerated/verified.
- GPL-3.0 applies to anything embedding moonlight-common-c or forking
  moonlight-qt — the new client is GPLv3, full stop.
