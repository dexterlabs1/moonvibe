# Engineering notes — lessons with full context

Chronological war stories from the build sessions. CLAUDE.md carries the
distilled rules; this file explains *why* each rule exists.

## Session 1 (2026-08-19): P0 fork + P1 shell v1

### Repo bootstrap

- The Claude GitHub App **cannot create repositories** (403 on
  `create_repository`) — the user creates the empty repo at github.com/new,
  then it's attached to the session. An empty `list_repos` hit for a repo the
  user swears exists means it genuinely doesn't (that's how we caught a
  creation that never went through).
- History import: plain `git clone --recurse-submodules` of
  moonlight-stream/moonlight-qt, remote-renamed to `upstream`, new `origin`
  added, `main` pushed FIRST so GitHub makes it the default branch, then
  `master` as the upstream mirror. **Tag pushes 403 through the session git
  proxy** (branches fine) — upstream's 70 release tags were left behind
  (fetchable from upstream any time); our own tags are created server-side by
  the Release workflow.

### CI archaeology (four attempts to first green release)

1. `ghcr.io/flathub-infra/flatpak-github-actions:kde-6.11` → `manifest
   unknown`. Don't guess third-party image tags; we run `flatpak-builder`
   directly on the stock runner instead (apt install flatpak flatpak-builder,
   add flathub remote, `--install-deps-from=flathub`).
2. Flatpak job hung **80+ minutes on the apt install step that normally takes
   25 seconds** (runner flake, steps API frozen while the AppImage job's steps
   updated live — that contrast is how you tell a hang from API staleness).
   Mitigation now in the workflow: `DEBIAN_FRONTEND=noninteractive`,
   `NEEDRESTART_MODE=a`, `Dpkg::Lock::Timeout`, `timeout-minutes` on step and
   job. A repeat is flake: just cancel + re-dispatch once.
3. SDL2_ttf inside the flatpak: the **CMake build installs no SDL2_ttf.pc**,
   so moonlight's qmake `PKGCONFIG += SDL2_ttf` dies ("SDL2_ttf development
   package not found" — that error string is qmake's link_pkgconfig.prf, not
   our code). Switched the module to autotools… which then tried to regenerate
   `aclocal.m4` (git checkout timestamps) with automake the KDE SDK doesn't
   ship (`aclocal-1.16: command not found`). Final fix, do not regress:
   `buildsystem: simple` with `touch aclocal.m4 configure Makefile.in` BEFORE
   `./configure --prefix=/app && make && make install`. configure itself
   generates SDL2_ttf.pc — the log line `config.status: creating SDL2_ttf.pc`
   is the health check.
4. Green: AppImage ~21–26 min, Flatpak ~25–45 min, release job publishes both
   with the Deck install guide and creates the tag.
5. (v0.2.0 attempt 1) The apt install step blew its 10-min timeout while
   genuinely downloading: flatpak-builder's *recommends* pull ~123 packages /
   99 MB (all of ffmpeg, pocketsphinx…) and Azure mirrors have slow days.
   Fixed with `--no-install-recommends` (+15-min timeout). Distinguish from
   case 2's hang by reading the log: steady Get:N lines = slow, not stuck.

- `on: push` **never fires** for proxy pushes in this environment — every
  workflow needs `workflow_dispatch:` and manual dispatch after pushing.
- `get_job_logs` with small tail shows only post-job git cleanup; use
  `tail_lines: 120+`. In-progress job logs return 404.

### Local dev container

- Full build works in the session container: apt the Qt6/FFmpeg/SDL dep list
  (CLAUDE.md), `qmake6 ../..../moonlight-qt.pro && make -j release` in an
  out-of-tree dir (we use `build/local/`, gitignored upstream). ~90 s compile.
- QML errors are runtime-only. The Xvfb+import+xdotool harness in CLAUDE.md is
  how the v0.2.0 shell was verified: screenshot, Read the png, click/keypress,
  screenshot again. The no-GPU container always pops the "no hardware
  decoder" dialog first — dismiss with Return; its presence is expected, and
  handy for checking modal styling.
- Traps that burned time: screenshotting a **stale instance** launched before
  the relink (always kill + relaunch after make; verify with `ps -o lstart`);
  `strings` can't grep QML out of the binary (rcc compresses; matches you do
  find come from embedded .qm translations); `pkill -f moonvibe` killed the
  invoking shell itself (the pattern matched the wrapper's command line —
  exit 144).

### QML specifics discovered

- `Overlay.modal` attached to ApplicationWindow → "Non-existent attached
  object" load failure on Qt 6.4. Attach on the Popup/Dialog (we put it in
  NavigableDialog, which NavigableMessageDialog inherits).
- The Material default modal dim is LIGHT gray — looks like a broken white
  background over our dark theme. The dark scrim in NavigableDialog fixes all
  dialogs at once.
- Singleton via `pragma Singleton` + `app/gui/qmldir` works from qrc with the
  implicit directory import, but **both files must be listed in app/qml.qrc**.
- Existing C++ models exposed to the grids: ComputerModel roles include
  `statusUnknown/online/paired/wakeable/name/details`; AppModel roles include
  `name/boxart/running/hidden/directLaunch/appid`. `appIcon.isPlaceholder`
  (set from known placeholder image dimensions) is the hook for monogram tiles.
- Gamepad→key mapping (sdlgamepadkeynavigation.cpp): A=Return, B=Escape,
  X=Menu, Y/Start=Hangup(settings), and settings has an A/B X/Y swap option
  that swaps SDL buttons before translation — footer hints stay truthful
  either way.

### Product/state facts a fresh session needs

- User: Dexter (dexterlabs1), host PC runs **Vibepollo** (so P3 ABR is
  buildable against their real setup), Steam Deck has Moonvibe installed and
  v0.1.0 verified working (pairing, streaming, Gaming Mode).
- Releases so far: v0.1.0 (rebranded moonlight-qt master), v0.2.0 (dark
  Deck-first shell — Theme singleton, footer glyph hints, host cards, monogram
  capsules, dark dialogs).
- Origin story docs also live in the user's Purple-meadows-games repo on
  branch `claude/moonlight-steam-deck-client-5k72kt` (docs/moonlight-deck/);
  the copies here in docs/ are canonical now.
