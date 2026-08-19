# Claude Code guide — Moonvibe

Deck-first fork of moonlight-qt (C++ / Qt6 QML / SDL2 / FFmpeg / GPLv3).
Read [docs/PRODUCT.md](docs/PRODUCT.md) (vision, UI spec, roadmap) and
[docs/RESEARCH.md](docs/RESEARCH.md) (ecosystem facts) before feature work.
Pick the next unchecked task in [BACKLOG.md](BACKLOG.md) top to bottom; check it
off in the same commit.

## Build

```bash
qmake6 moonlight-qt.pro   # root .pro keeps upstream name deliberately
make release              # or: make debug
```

Linux deps: see README. CI (`.github/workflows/`) builds an AppImage
(ubuntu-22.04, deps from source) and a Flatpak bundle
(`packaging/flatpak/io.github.dexterlabs1.Moonvibe.json`, KDE 6.11 runtime,
builds the checked-out tree via a `dir` source) on every push.

## Repo layout & identity

- `app/` — the client. Identity lives in `app/main.cpp` (org/app name,
  desktop-file name, SDL WMCLASS — all must stay `io.github.dexterlabs1.Moonvibe`
  and in sync with `app/deploy/linux/io.github.dexterlabs1.Moonvibe.desktop`).
  Version: `app/version.txt` (read by qmake and the AppImage script).
- `moonlight-common-c/`, `qmdnsengine/`, `app/SDL_GameControllerDB` —
  submodules (nested: `enet`, `nanors` under common-c). Always clone/checkout
  with `--recurse-submodules`.
- `packaging/flatpak/` — manifest + gamescope WSI layer JSON + libplacebo patch.
- `updates/qt.json` — update-check manifest served raw from `main` (AppImage
  builds only; Flatpak never runs the checker).

## Branch & upstream policy

- `main` (default) = Moonvibe. `master` = clean mirror of
  `moonlight-stream/moonlight-qt` master.
- Upstream sync: `git fetch upstream && git checkout master && git merge
  upstream/master && git push origin master`, then merge `master` into `main`.
  Never rebase published history.
- Keep diffs vs upstream minimal outside new files; don't rename upstream files
  without need (merge friction). Windows/macOS/SteamLink files stay in-tree but
  unmaintained.

## Things that will bite you

- The gamescope WSI Vulkan layer (`ENABLE_GAMESCOPE_WSI`) is required for HDR
  in Gaming Mode and has broken before on SteamOS updates (moonlight-qt #1930).
  Test Flatpak artifacts on the Deck's beta channel when touching video/Vulkan.
- moonlight-common-c requires its bundled ENet fork — never swap in stock ENet.
- Bitrate/res/FPS are negotiated at RTSP SETUP; mid-stream changes need the
  Vibepollo ABR dialect (P3) or a reconnect. See PRODUCT.md §2.2.
- The repo is **private**: must go public before distributing any build (GPLv3).
- Settings land in `~/.config/Moonvibe/Moonvibe.conf`; there is no migration
  from upstream Moonlight configs yet (deliberate — BACKLOG).
