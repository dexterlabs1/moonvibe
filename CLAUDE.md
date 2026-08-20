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

## Local build (WSL2 on the Windows dev PC) — verified 2026-08-19

Development runs on a Windows workstation in **WSL2 Ubuntu 26.04**, not on
Windows natively and not in CI. `$SRC` below is the checkout path. A full
`make -j$(nproc) release` takes under a minute on a 32-thread machine.

```bash
# one-time: build deps (see the apt list above) inside the Ubuntu distro
mkdir -p ~/build/moonvibe && cd ~/build/moonvibe
qmake6 $SRC/moonlight-qt.pro
make -j$(nproc) release          # binary at ~/build/moonvibe/app/moonvibe
```

- **Shadow-build into `~/…` on ext4, never into the source tree.** The repo
  may live under a syncing cloud folder, where build output causes sync churn
  and cloud-placeholder reads that fail.
- Source is read over `/mnt/c` (9p), which caps the build at ~640 % CPU of a
  possible 3200 %. Fine for iteration. For anything heavier, `rsync -a
  --exclude .git --exclude build` the tree to `~/src/moonvibe` first — the
  working tree is only ~9 MB, so the sync is seconds.
- **Force X11 for the Xvfb harness or the screenshot comes back blank**: WSLg
  exports a Wayland display and the app takes it in preference to `:99`.
  `env -u WAYLAND_DISPLAY DISPLAY=:99 QT_QPA_PLATFORM=xcb SDL_VIDEODRIVER=x11 ./moonvibe`
- **Hardware decode works in WSL** — `/dev/dxg` is exposed, FFmpeg selects
  `hevc_cuvid` on the RTX 5090. The "no hardware decoder" dialog that the cloud
  container always raised does NOT appear here, so don't write test steps that
  assume it.
- **The dev PC can also be the Vibepollo host**, so the client can be built and
  tested against a real host in one place. Under default WSL networking the host
  answers on the WSL gateway (`ip route show default`); under mirrored
  networking it answers on `127.0.0.1`.
- **Discovery stalls at "Connecting…" under default WSL networking**: the host
  name resolves to a public IPv6 address that WSL2's NAT cannot route. Fix with
  `%USERPROFILE%\.wslconfig` → `[wsl2]` / `networkingMode=mirrored` (needs
  `wsl --shutdown`), or add the host by its gateway IP.
- **Bumping `app/version.txt` does not rebuild anything.** `VERSION_STR` is
  baked in at qmake time from `$$cat(version.txt)`, but the generated Makefile
  does not list `version.txt` as a dependency, so an incremental `make` keeps
  the old string and the UI reports the previous version. Same trap for any
  `DEFINES` change: editing a `-D` does not invalidate already-compiled objects.
  After a version bump, delete `app/Makefile*` in the build dir, re-run qmake6,
  and touch `app/backend/systemproperties.cpp`. Flatpak/AppImage builds are
  clean builds, so releases were never wrong -- only local incremental ones.
- Flatpak/AppImage artifacts for the Deck can also be built locally —
  `flatpak-builder` needs `flatpak flatpak-builder elfutils` (see the CI note
  about `eu-strip`).

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

- **From the Windows dev PC, normal `git push` DOES trigger `on: push`
  workflows** and the `gh` CLI is authenticated (`gh run list/view --log-failed`,
  `gh workflow run`). The old warnings below applied only to the cloud
  sandbox's git proxy — do not carry them over blindly:
  - ~~pushes do not trigger `on: push`~~ — contradicted by two push-triggered
    Build runs on 2026-08-19.
  - the tag-push 403 may still have been real; the Release workflow creates the
    tag server-side (softprops/action-gh-release) regardless, so there is still
    no reason to `git push origin --tags`.
- Manual dispatch is still the way to cut a release:
  `gh workflow run release.yml --ref main -f version=X.Y.Z`.
- Release workflow = build-appimage (~21–26 min) + build-flatpak (~25–45 min)
  + release job publishing both assets with Deck install instructions.
- Babysit runs with `actions_list`/`get_job_logs` (`tail_lines: 120` — the real
  error sits above post-job cleanup noise). In-progress job logs 404. Job step
  lists update live; a step frozen >30 min on something that took seconds
  before = hung runner → cancel, re-dispatch (timeouts now fail these fast).
- Releases: **v0.1.0 only** (stock+rebrand). Verified on the user's Deck at
  v0.1.0: pairing, streaming, Gaming Mode all work. **v0.2.0 (dark shell) is
  built but NOT released** — every Release run since has failed in the Flatpak
  job, and the `release` job `needs:` both artifacts, so no tag is ever cut.
  Root cause: `--no-install-recommends` dropped `elfutils`, so flatpak-builder
  could not find `eu-strip` and died at the libplacebo module.

## The in-stream drawer (how it works)

The drawer CANNOT be QML. Streaming happens in a plain `SDL_CreateWindow`; the
Qt window is hidden. The only route to the screen over live video is
`OverlayManager`, which holds one atomic `SDL_Surface*` per overlay type that
each renderer takes, uploads and blits.

- `app/streaming/streamdrawer.{h,cpp}` renders the panel into an SDL surface: a
  small software rasteriser (rounded rects with antialiased corners, strokes as
  true annuli) plus SDL_ttf using the bundled Manrope/Space Grotesk from `:/fonts`.
- `OverlayDrawer` + `OverlayManager::updateOverlaySurface()` publish it. Nothing
  in that pipeline was ever text-specific -- it had only ever been given text.
- Every renderer needs a position case: `sdlvid`, `eglvid` (GL origin is
  LOWER-LEFT, and it asserts on unknown overlay types), `plvk`, `drm`. The Deck
  runs plvk/drm under gamescope, so skipping those means it works everywhere
  except the target device.
- Input is intercepted in `keyboard.cpp` before anything reaches the host, so a
  stray arrow press cannot leak into the game while the menu is open.

**Verify it without a stream:** `MOONVIBE_DRAWER_PREVIEW=/tmp/d.bmp ./moonvibe`
renders the panel and exits. Rendering depends only on the state set on it, so
this needs no host, no session, and no working Qt Quick pipeline.

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
