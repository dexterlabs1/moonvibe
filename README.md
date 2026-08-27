# Moonvibe

**A Deck-first game-streaming client** — a fork of
[moonlight-qt](https://github.com/moonlight-stream/moonlight-qt) rebuilt around
the Steam Deck, pairing best with [Vibepollo](https://github.com/Nonary/Vibepollo)
and [Apollo](https://github.com/ClassicOldSong/Apollo) hosts while staying fully
compatible with stock [Sunshine](https://github.com/LizardByte/Sunshine).

> **Status: early, but shipping.** Six releases are out; the latest, 0.6.0,
> brings a dark Deck-first UI shell, a library with a Continue row, host cards,
> pairing PIN tiles, and menus/dialogs rebuilt on the design system. It installs
> from the signed Flatpak repo at <https://dexterlabs1.github.io/moonvibe/>,
> with updates delivered through Discover — see the install section below. An
> in-stream settings drawer and rebindable shortcuts are done on `main` but not
> yet released; see [BACKLOG.md](BACKLOG.md) and [docs/PRODUCT.md](docs/PRODUCT.md)
> for what's next.


## Install on a Steam Deck

In **Desktop Mode**, open <https://dexterlabs1.github.io/moonvibe/> and click
the `.flatpakref` link. Discover adds Moonvibe as a software source and
installs it. That is the whole thing.

From then on **updates arrive in Discover's normal update list** -- no
downloads, no files, no terminal. This is the recommended route and the only
one that stays effortless.

To reach it from Gaming Mode, open the application launcher, right-click
**Moonvibe**, and choose *Add to Steam*. You only do that once; updates keep
the shortcut working.

### Coming from a `.flatpak` file?

Bundles have no source behind them, so Flatpak can never update one and each
install lands in whichever scope the installer picked. Remove the bundle copies
first, then install from the repo above, so exactly one install exists:

```
flatpak uninstall --user --system -y io.github.dexterlabs1.Moonvibe
flatpak install --user -y https://dexterlabs1.github.io/moonvibe/moonvibe.flatpakref
```

### Single-file download

Releases still carry a `Moonvibe-*.flatpak` for offline installs. It works, but
it is the manual path -- you own the upgrading. See the traps below.

### If it does not upgrade, or you are unsure what is installed

Open **Konsole** and paste this. It only reads -- it changes nothing:

```
flatpak list --app --columns=application,version,branch,installation | grep -i moon ; ls ~/Downloads/*.AppImage ~/Downloads/*.flatpak 2>/dev/null
```

That prints every installed Moonvibe, its version, and whether it is a `user`
or `system` install -- and whether an old AppImage is still sitting in your
Downloads folder.

**An AppImage is not a Flatpak.** If you installed an early build by
downloading `Moonvibe-*.AppImage` and running it, Flatpak knows nothing about
that file and cannot upgrade it. It keeps its own icon and keeps launching the
old version no matter how many Flatpaks you install. Delete the AppImage and
use the Flatpak.

### Two installs at once (the one that will actually catch you)

Flatpak has two separate installation scopes, `user` and `system`, and **the
user one wins** when the same app is in both. Discover may put a new version in
`system` while an old version stays in `user`; every launch then runs the old
one, and nothing about the UI tells you. The listing above shows it plainly:

```
io.github.dexterlabs1.Moonvibe   0.3.0   master   system
io.github.dexterlabs1.Moonvibe   0.1.0   master   user
```

Remove the stale copy so exactly one remains:

```
flatpak uninstall --user -y io.github.dexterlabs1.Moonvibe
```

Note that `flatpak install --or-update` only touches the scope you aim it at,
so it cannot fix this on its own.

### Install or upgrade from a file, reliably

```
flatpak install --user --or-update -y ~/Downloads/Moonvibe-0.3.0.flatpak
```

`--or-update` is the part that matters: plain `flatpak install` refuses when the
app is already present instead of upgrading it.

### Which one am I running?

Open Moonvibe and tap the gear icon -- the Settings screen shows the version in
the top bar. Anything from 0.2.0 onward has a near-black top bar reading
**Hosts**. If you see a blue toolbar reading **Computers**, that is 0.1.0, which
was upstream Moonlight with only the name changed.

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
