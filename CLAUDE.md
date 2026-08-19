# Claude Code guide — Moonvibe

Deck-first fork of moonlight-qt (C++ / Qt6 QML / SDL2 / FFmpeg / GPLv3).
Read [docs/PRODUCT.md](docs/PRODUCT.md) (vision, UI spec, roadmap) and
[docs/RESEARCH.md](docs/RESEARCH.md) (ecosystem facts) before feature work.
Pick the next unchecked task in [BACKLOG.md](BACKLOG.md) top to bottom; check it
off in the same commit. Session war stories with full context:
[docs/ENGINEERING_NOTES.md](docs/ENGINEERING_NOTES.md).

UI mockups (all six target screens, 1280×800):
https://claude.ai/code/artifact/16b29028-036a-4777-8b59-455f1c2fe70a

## Build & verify (do this before every push)

```bash
qmake6 moonlight-qt.pro          # root .pro keeps upstream name deliberately
make release                      # binary at <builddir>/app/moonvibe
```

Debian/Ubuntu build deps: `qmake6 qt6-base-dev qt6-declarative-dev
libqt6svg6-dev libegl1-mesa-dev libgl1-mesa-dev libopus-dev libsdl2-dev
libsdl2-ttf-dev libssl-dev libavcodec-dev libavformat-dev libswscale-dev
libva-dev libvdpau-dev libxkbcommon-dev wayland-protocols libdrm-dev`.
Runtime QML modules (needed to actually launch): `qml6-module-qtquick-controls
qml6-module-qtquick-templates qml6-module-qtquick-layouts
qml6-module-qtqml-workerscript qml6-module-qtquick-window qml6-module-qtquick`.

**Visual smoke test harness** (QML errors only appear at runtime):
```bash
Xvfb :99 -screen 0 1280x800x24 &                     # apt: xvfb imagemagick xdotool
DISPLAY=:99 QML_DISK_CACHE_PATH=/tmp/qmlcache ./moonvibe > /tmp/ui.log 2>&1 &
sleep 8 && DISPLAY=:99 import -window root shot.png  # then Read the png
DISPLAY=:99 xdotool key Return                        # dismiss the no-GPU decoder dialog
grep "failed to load component" /tmp/ui.log           # must be absent
```
Gotchas: relaunch the app after every relink (a stale instance shows old QML —
check `ps -o lstart` if the UI looks wrong); wipe the QML_DISK_CACHE_PATH dir;
never `pkill -f` a pattern that matches your own shell command line.

## QML architecture (added by Moonvibe)

- `app/gui/Theme.qml` — singleton design tokens (registered via `app/gui/qmldir`;
  both listed in `app/qml.qrc` — new QML files MUST be added there or they
  silently don't ship). Use `Theme.accent`, `Theme.monogramTop(name)`, etc.
- Footer hints: every view exposes `property var navHints: [{b:"A",t:"..."}]`;
  `main.qml`'s footer renders them via `NavHint.qml`. Empty list hides the bar
  (StreamSegue/QuitSegue). Gamepad truth (sdlgamepadkeynavigation.cpp):
  A→Return/select, B→Escape/back, X→Menu key/context menu, Y & Start→Hangup→settings.
- Dark modal scrim lives on `NavigableDialog` (`Overlay.modal`); attaching
  `Overlay.modal` to ApplicationWindow FAILS at load ("Non-existent attached
  object") on Qt 6.4 — keep it on popups.
- Views: PcView (host status cards), AppView (capsule grid, monogram
  placeholder tiles via `appIcon.isPlaceholder`, RUNNING badge), SettingsView
  (1816 lines, inherits Material dark, not yet reworked).

## Repo layout & identity

- Identity: `app/main.cpp` (org/app name, desktop-file name, SDL WMCLASS — all
  `io.github.dexterlabs1.Moonvibe`, must stay in sync with
  `app/deploy/linux/io.github.dexterlabs1.Moonvibe.desktop`). Version:
  `app/version.txt` (also update the appdata `<releases>` and `updates/qt.json`
  when bumping).
- Submodules (clone with `--recurse-submodules`, 2 levels):
  moonlight-common-c (→ enet fork + nanors), qmdnsengine, SDL_GameControllerDB.
- `packaging/flatpak/io.github.dexterlabs1.Moonvibe.json` — builds the
  checked-out tree (`dir` source, skips .git/build). SDL2_ttf module MUST stay
  `buildsystem: simple` with the `touch` first (see ENGINEERING_NOTES).
- `updates/qt.json` — AppImage update-check manifest served raw from `main`.

## Branch & upstream policy

- `main` (default) = Moonvibe. `master` = clean mirror of moonlight-stream/moonlight-qt.
- Upstream sync: fetch upstream → merge into `master` → push → merge `master`
  into `main`. Never rebase published history. Keep diffs outside new files
  minimal (merge friction). Windows/macOS/SteamLink files stay in-tree, unmaintained.

## CI / release runbook (GitHub, via MCP tools)

- **Pushes through this environment's git proxy do NOT trigger `on: push`
  workflows.** Always dispatch manually:
  `actions_run_trigger run_workflow release.yml ref=main inputs={"version":"X.Y.Z"}`.
- **Tag pushes 403 through the proxy.** The Release workflow creates the tag
  server-side (softprops/action-gh-release) — never `git push origin --tags`.
- Release workflow = build-appimage (~21–26 min) + build-flatpak (~25–45 min)
  + release job publishing both assets with Deck install instructions.
- Babysit runs with `actions_list`/`get_job_logs` (`tail_lines: 120` — the real
  error sits above post-job cleanup noise). In-progress job logs 404. Job step
  lists update live; a step frozen >30 min on something that took seconds
  before = hung runner → cancel, re-dispatch (timeouts now fail these fast).
- Releases: v0.1.0 (stock+rebrand), v0.2.0 (dark shell). Verified on the
  user's Deck at v0.1.0: pairing, streaming, Gaming Mode all work.

## Things that will bite you

- The gamescope WSI Vulkan layer (`ENABLE_GAMESCOPE_WSI`) is required for HDR
  in Gaming Mode and has broken on SteamOS updates (moonlight-qt #1930) — test
  Flatpak artifacts on the Deck when touching video/Vulkan.
- moonlight-common-c requires its bundled ENet fork — never swap in stock ENet.
- Bitrate/res/FPS are negotiated at RTSP SETUP; mid-stream changes need the
  Vibepollo ABR dialect (P3, host ≥1.18) or a reconnect. PRODUCT.md §2.2.
- The repo is **private**: must go public before distributing builds (GPLv3).
  The user's host runs **Vibepollo**; their Deck has v0.1.0+ installed.
- Settings land in `~/.config/Moonvibe/Moonvibe.conf`; no migration from
  upstream Moonlight configs (deliberate — BACKLOG).
- 28 translation `.ts` files still say "Moonlight" (deferred).
