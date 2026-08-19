# Moonvibe

**A Deck-first game-streaming client** — a fork of
[moonlight-qt](https://github.com/moonlight-stream/moonlight-qt) rebuilt around
the Steam Deck, pairing best with [Vibepollo](https://github.com/Nonary/Vibepollo)
and [Apollo](https://github.com/ClassicOldSong/Apollo) hosts while staying fully
compatible with stock [Sunshine](https://github.com/LizardByte/Sunshine).

> **Status: pre-alpha (P0).** This repo is a full-history import of upstream
> moonlight-qt `master` with a rebrand and Deck-focused packaging. The fun parts
> — controller-first UI, in-stream settings drawer, live ABR bitrate, Decky
> Quick Access plugin — are being built next; see [BACKLOG.md](BACKLOG.md) and
> [docs/PRODUCT.md](docs/PRODUCT.md).
>
> The repo is private while it takes shape. It must go public before any build
> is distributed (GPLv3).

## Why

moonlight-qt is excellent but release-starved and conservative; the
Deck-focused forks stalled; and Vibepollo shipped host-side live-bitrate (ABR)
negotiation that no client consumes yet. Moonvibe unifies the proven ideas
(Artemis's in-stream menu, chiaki-ng's Deck-native UX, MoonDeck's Steam
integration) in one maintained, Deck-first client. Full research:
[docs/RESEARCH.md](docs/RESEARCH.md).

## Building (Linux)

Same toolchain as upstream moonlight-qt (the root project file keeps its
upstream name to ease merges):

```bash
sudo apt install qt6-base-dev qt6-declarative-dev libqt6svg6-dev \
  libegl1-mesa-dev libgl1-mesa-dev libopus-dev libsdl2-dev libsdl2-ttf-dev \
  libssl-dev libavcodec-dev libavformat-dev libswscale-dev libva-dev \
  libvdpau-dev libxkbcommon-dev wayland-protocols libdrm-dev
git clone --recurse-submodules https://github.com/dexterlabs1/moonvibe.git
cd moonvibe
qmake6 moonlight-qt.pro
make release
```

CI builds an AppImage and a Flatpak bundle
(`io.github.dexterlabs1.Moonvibe`) on every push — grab them from the Actions
artifacts. The Flatpak manifest lives in
[`packaging/flatpak/`](packaging/flatpak/).

## Install on a Steam Deck (current, manual)

1. Download the `moonvibe.flatpak` artifact from the latest green Actions run.
2. In Desktop Mode: `flatpak install --user ./moonvibe.flatpak`.
3. Add to Steam: right-click Moonvibe in the app menu → *Add to Steam*, then
   return to Gaming Mode.

(A one-paste installer and Flathub/Decky-store distribution come later —
see the roadmap.)

## Credits & license

Moonvibe stands on [moonlight-qt](https://github.com/moonlight-stream/moonlight-qt)
and [moonlight-common-c](https://github.com/moonlight-stream/moonlight-common-c)
by Cameron Gutman and the Moonlight team (upstream README preserved at
[docs/UPSTREAM_README.md](docs/UPSTREAM_README.md)), with ideas from
[Artemis](https://github.com/ClassicOldSong/moonlight-android),
[chiaki-ng](https://github.com/streetpea/chiaki-ng),
[MoonDeck](https://github.com/FrogTheFrog/moondeck), and
[Vibepollo](https://github.com/Nonary/Vibepollo).

Licensed under **GPL-3.0** (inherited from upstream). See [LICENSE](LICENSE).
