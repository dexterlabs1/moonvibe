# Product: a modern Moonlight client for Steam Deck

*Vision, feature set, UI design spec, and phased roadmap. Factual grounding and
all source links live in [RESEARCH.md](RESEARCH.md).*

**Working title:** *Moondeck-era Moonlight* — pick a real name before the repo
is created (must not collide with "MoonDeck" the Decky plugin; candidates:
**Lumen**, **Nightbeam**, **Perigee**, **Moonrise**). The doc below uses
"the client."

> **Repo note:** the client is a separate project — create a fresh repository
> for it (GPLv3, inherited from moonlight-qt/moonlight-common-c). This doc set
> is parked in Purple-meadows-games only until that repo exists.

---

## 1. Vision

**The Vibepollo of clients:** a fast-moving, Deck-first fork of moonlight-qt
that keeps the upstream streaming pipeline (Vulkan/libplacebo HDR rendering,
FFmpeg + Vulkan Video decode, moonlight-common-c protocol) and replaces
everything around it:

1. **A console-grade UI** — chiaki-ng-quality QML, 100% controller-complete,
   wizard onboarding, per-host → per-app settings inheritance, real artwork.
2. **In-stream control** — a QAM-style drawer and trackpad radial inside the
   stream; live bitrate via **Vibepollo ABR** (first client to ship it);
   "soft reconnect" to make resolution/FPS/HDR changes feel instant.
3. **Deck-native integration** — a companion **Decky plugin** driving the
   client over a localhost control API (live settings from the Quick Access
   panel, mid-game), Steam-shortcut creation, host wake/sleep, and native
   gyro/mic/haptics.

Primary host target: **Vibepollo** (superset of Apollo dialect). Everything
must degrade gracefully against stock Sunshine — fork features light up when
the host supports them (capability badges in the UI, never hard failures).

---

## 2. Feature set

### 2.1 Table stakes (inherited from moonlight-qt v6.x)

H.264/HEVC/AV1 decode (VAAPI + Vulkan Video), HDR10 on Deck OLED under
gamescope, E2E encryption, 5.1/7.1 audio, WoL, pairing with stock Sunshine.

### 2.2 The headline features (why this client exists)

| Feature | What it does | Prior art / dependency |
|---|---|---|
| **Live bitrate (ABR)** | Drag a slider mid-stream; NVENC hosts adjust seamlessly, others fast-restart the encoder + IDR resync. Optional auto mode driven by loss/jitter (Parsec-style). | Vibepollo ≥ 1.18 ABR negotiation — no mainstream client has it |
| **In-stream drawer** | Select+L5 (configurable): slide-in panel with bitrate, res/FPS/HDR, input modes, mic, stats tier, keyboard, quit | Artemis Quick Menu, SteamOS QAM pattern |
| **Soft reconnect** | Res/FPS/HDR changes reuse pairing + control session, restart only RTSP/RTP behind a freeze-frame + spinner (~1–2 s instead of full teardown) | Novel; taxonomy in RESEARCH §3 |
| **Decky QAM plugin** | Live session stats, bitrate slider, end stream, wake/sleep host — from the Quick Access panel over any running stream | MoonDeck (relaunch-only) + PowerTools (live QAM) fused via our control API |
| **Per-host → per-app profiles** | Global defaults ⊂ host profile ⊂ per-app override, auto-applied on connect; import/export | #1187/#1795/#1327/#213; StreamLight |
| **Gyro passthrough** | Read Deck raw HID sensors (bypass Steam Input's gyro gap), present DS4 motion to the host | chiaki-ng's proven approach; qt #1123/#960 |
| **Mic passthrough** | Deck mic → Opus over control channel → host virtual mic (Discord on host hears you) | Apollo mic PR #1428, Vibelight |
| **Clipboard sync, server commands, OTP pairing, virtual-display control** | The Apollo dialect features Artemis Android has and desktop never got | Apollo/Vibepollo hosts |
| **Resilience** | Auto-reconnect with retry-forever, suspend/resume resync (stream survives Deck sleep), WoL with separate-MAC option | #1379, #665, #1619 |
| **Connection health as ambient UI** | Corner 0–4 bars; escalating actionable warnings ("5 GHz band congested — lower bitrate?" one-tap apply) | GFN meter + Parsec warnings |
| **Artwork-rich library** | SteamGridDB enrichment (capsule/hero/logo) over host `appasset` fallback, local cache, per-app override; "running now" resume card | SteamGridDB ecosystem; qiin2333 fork |
| **90 fps mode** | First-class 90 Hz OLED support incl. refresh-match prompts for pacing | Deck OLED panel; pacing issues #795/#1191 |

### 2.3 Deliberate non-goals (v1)

- No protocol rewrite (no QUIC/WebTransport) — stay wire-compatible with every
  Sunshine-family host.
- No host-side software of our own — lean on Vibepollo's API tokens; only add a
  Buddy-style helper if a need survives contact with reality.
- No Windows/macOS builds until the Deck experience is done (Linux desktop
  comes free-ish; don't let it drive decisions).

---

## 3. UI design spec

> **Visual mockups:** all six screens below are mocked up at the Deck's native
> 1280×800 on a design canvas —
> <https://claude.ai/code/artifact/16b29028-036a-4777-8b59-455f1c2fe70a>
> (home/library, in-stream drawer, trackpad radial, Decky Quick Access panel,
> pairing wizard, per-host settings).

### 3.1 Design language

- **Dark, OLED-first**: near-black `#0e0e12` base (dome-style true blacks),
  soft indigo/moonlight accent, Valve-adjacent typography sizes (min 16 px
  body at 1280×800 — XBPlay's small fonts are the cautionary tale).
- **SteamOS-native idioms**: persistent footer with controller glyph hints
  (`Ⓐ Select · Ⓑ Back · Ⓧ Options · ☰ Menu`), right-side slide-in drawers,
  capsule grids, hero rows. The client should feel like an extension of Gaming
  Mode, not a desktop app trapped in it.
- **One spatial-navigation system for 100% of surfaces.** Every dialog, toast,
  and error is focusable and dismissible with Ⓑ. (The single loudest
  moonlight-qt failure is piecemeal nav.) Touch always works too — every
  control is a large touch target.
- **Never require the OS keyboard.** PIN entry, search, and renames use
  on-screen D-pad-navigable widgets (the Steam+X keyboard is broken for
  non-Steam apps in Game Mode).

### 3.2 Screens

**1. Home / Library**
- Top bar: current host pill (name + reachability dot + latency), host
  switcher on Ⓨ, settings gear, connection-health chip.
- Hero row: "Continue" cards for recent apps; if a session is live on the host,
  the first card is a **Resume** card with a live thumbnail badge ("Running on
  TOWER — 12 min").
- Below: capsule grid (600×900 SteamGridDB art, `appasset` fallback,
  monogram placeholder tile as last resort). L1/R1 jump between rows;
  hold direction accelerates.
- Empty/edge states are first-class: host asleep → big "Wake TOWER" button
  (WoL); host unpaired → "Pair" wizard entry; host offline → retry + help.

**2. In-stream drawer** (Select+L5 default, configurable; also trackpad radial
→ "More")
- Right-side slide-in over the live video (video keeps running, input to game
  is suspended while drawer is open).
- Sections top-to-bottom:
  - *Session*: app name, duration, health bars, current codec/res/fps chip.
  - *Bitrate*: slider 1–150 Mbps with **ABR badge** when host is Vibepollo
    ("live" vs "brief hiccup" hint text per encoder); Auto toggle.
  - *Display*: resolution & FPS pickers and HDR toggle, each marked with a
    small ⟳ "quick restart" glyph (soft reconnect); frame-pacing mode.
  - *Input*: mouse mode (game / touchpad / multi-touch / local cursor /
    disabled), gyro toggle, controller-passthrough indicator.
  - *Audio*: mic mute (with level meter), output config.
  - *Actions*: on-screen keyboard, stats tier (0–3), clipboard sync (Apollo
    hosts), server commands list, **Quit** (hold Ⓐ with progress ring —
    no accidental exits, no hardcoded chord collisions).

**3. Trackpad radial** (right trackpad press, Steam-Input-style with haptic
ticks) — 4 sectors: Mic mute · Stats tier cycle · Keyboard · Drawer. Fastest
actions, zero navigation.

**4. Decky Quick Access panel** (companion plugin, native `@decky/ui` look)
- When streaming: session stats sparkline, bitrate slider (drives the same
  control API), End Stream, screenshot.
- Always: host list with wake/sleep/restart buttons, "Launch last app,"
  plugin/client version + update check.

**5. Pairing wizard** (first-run and add-host)
- Steps: auto-discover (mDNS) → pick host → **4-digit PIN shown huge** with a
  D-pad PIN pad *on the host's web UI via deep link where possible; OTP
  pairing when the host is Apollo/Vibepollo (no host-side typing at all)* →
  bandwidth probe → recommended defaults (codec by decode support, bitrate by
  probe, 90 Hz prompt on OLED) → optional **"Add to Steam"** (creates the
  non-Steam shortcut with artwork + recommended controller profile,
  chiaki-ng-style) → done.

**6. Settings**
- Left rail: Global · per-host pages · About.
- Host page shows the **inheritance model visibly**: each row displays its
  effective value and a small origin tag (`global` / `host` / `per-app`),
  with Ⓧ to override / reset. Per-app overrides live on the app's detail
  sheet in the library.
- Capability card per host: what this host supports (ABR, virtual display,
  clipboard, mic, 4:4:4) as pass/fail chips — doubles as diagnostics.

### 3.3 Stats & health model

- Tier 0: nothing. Tier 1: corner 0–4 bars. Tier 2: one-line
  `fps · ms · loss`. Tier 3: full decode/render/network breakdown.
- Event badges independent of tier: packet-loss burst, host encoder overload,
  Wi-Fi roam — each with a one-tap suggested fix (Parsec pattern).

---

## 4. Architecture sketch

```
┌───────────────────────────── Steam Deck ─────────────────────────────┐
│  Gaming Mode (gamescope)                                             │
│  ┌─────────────────────────────┐    ┌──────────────────────────────┐ │
│  │ The client (moonlight-qt    │    │ Decky plugin                 │ │
│  │ fork, QML UI + SDL input)   │◄──►│  React QAM panel             │ │
│  │  · moonlight-common-c       │ ws │  Python backend              │ │
│  │  · FFmpeg/VAAPI + Vulkan    │    │  (shortcuts, install/update) │ │
│  │  · libplacebo HDR present   │    └──────────────────────────────┘ │
│  │  · localhost control API    │                                     │
│  │  · raw-HID gyro reader      │                                     │
│  └──────────────┬──────────────┘                                     │
└─────────────────┼────────────────────────────────────────────────────┘
                  │ GameStream protocol (+ Apollo/Vibepollo dialect:
                  │ ABR negotiation, clipboard, commands, OTP, mic)
        ┌─────────▼─────────┐
        │ Vibepollo host    │  (graceful degradation to Apollo/Sunshine)
        └───────────────────┘
```

- **Control API:** WebSocket + JSON on `127.0.0.1` (token in a `/home` file
  both processes can read). Surface: get/set session params, stats stream,
  end-session, launch-app. This is what makes the QAM plugin *live* instead of
  MoonDeck's relaunch dance — and it doubles as a debug/e2e-test surface.
- **Why fork moonlight-qt rather than start clean:** the decode/present
  pipeline (Vulkan, libplacebo, HDR, frame pacing, years of platform quirks)
  is the crown jewel; Artemis Qt and Vibelight both validate the fork path.
  Cherry-pick their diffs where licenses align (all GPLv3).
- **UI rebuild, not restyle:** new QML shell with one nav system; keep
  upstream's session/stream classes. Track upstream master for pipeline fixes
  (e.g. the gamescope WSI crash, #1930).

---

## 5. Distribution & the "share with a friend" story

1. **Flatpak, own repo first** — GitHub Pages flatpak repo + a `.flatpakref`
   file: one click in Discover installs *and* wires updates. Flathub
   submission later (note: Flathub now rejects heavily-AI-generated
   submissions — plan for human-authored curation of the manifest and listing).
2. **One-paste installer** (Decky-installer pattern):
   `curl -sSL https://…/install.sh | sh` → installs the Flatpak, adds the
   non-Steam shortcut with artwork + controller profile, optionally installs
   the Decky plugin. Also ship a double-click `.desktop` version for the
   terminal-averse.
3. **Decky plugin** via the official store (testing-store channel doubles as a
   friends beta while the review PR is open); plugin can self-serve client
   updates.
4. AppImage explicitly **not** a supported channel (SteamOS churn keeps
   breaking Moonlight's — RESEARCH §4).

Friend flow target: *"Open this link on your Deck in Desktop Mode, click
Install, back to Gaming Mode."* Two minutes, no terminal.

---

## 6. Roadmap

- **P0 — Fork & foundation.** New repo (GPLv3), rebrand, build against latest
  upstream master, Flatpak manifest + own repo + CI, non-Steam shortcut
  helper. *Exit: stock-feature-parity client installable from a link, running
  in Gaming Mode with HDR.*
- **P1 — UI shell.** New QML shell: library/home, pairing wizard (OTP + PIN
  pad), settings with per-host/per-app inheritance, SteamGridDB artwork,
  100% controller nav. *Exit: never need a mouse or the OS keyboard.*
- **P2 — In-stream control.** Drawer + trackpad radial + configurable quit
  hold; stats tiers + health chip; localhost control API; **Decky plugin v1**
  (stats, end stream, wake/sleep). *Exit: change client-side settings and see
  stats mid-stream from drawer or QAM.*
- **P3 — Vibepollo dialect.** ABR client implementation (live bitrate slider +
  auto mode), soft reconnect for res/FPS/HDR, capability badges, server
  commands, clipboard, virtual-display toggle. *Exit: bitrate slides live on
  an NVENC Vibepollo host; res change ≤ 2 s.*
- **P4 — Deck-native deep cuts.** Raw-HID gyro → DS4 motion, mic passthrough
  (Apollo endpoint), suspend/resume resilience + retry-forever + WoL
  hardening, 90 Hz pacing polish. *Exit: Discord on host hears the Deck mic;
  gyro aims in-game; Deck sleep doesn't kill the session.*
- **P5 — Polish & publish.** Flathub + Decky store submissions, onboarding
  polish, docs site, telemetry-free diagnostics export.

Each phase ships an installable release — cadence over completeness is the
Vibepollo lesson.

## 7. Risks

- **Upstream/ecosystem drift:** SteamOS/gamescope updates break Vulkan WSI or
  VCN decode periodically → keep codec/renderer fallback UX, test on SteamOS
  beta channel.
- **Artemis Qt revival:** if it wakes up, evaluate merging efforts instead of
  competing (its author holds official Artemis branding).
- **Vibepollo ABR surface is young and informally specified** → implement
  against its source, keep the feature behind capability negotiation.
- **Decky fragility:** plugin can break on Steam client updates → the client
  must be fully usable without the plugin (drawer covers everything).
