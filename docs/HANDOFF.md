# Handoff — 2026-08-27 (updated end of Fable session)

State of Moonvibe at the end of the Opus session, for whoever picks this up next.
Read [ENGINEERING_NOTES.md](ENGINEERING_NOTES.md) first if anything below looks
surprising — the traps are recorded there.

## Where things stand

- `main` is pushed and clean. Working tree has no uncommitted changes.
- **The Deck runs 0.6.0.** Everything after that is on `main` but UNRELEASED:
  the in-stream drawer, rebindable shortcuts (+ Select+L5 drawer chord), and
  the Settings redesign. Next release = **0.7.0**, gated only on the owner's
  visual sign-off of Settings on WSLg (launched for them at session end).
- Releases: v0.6.0, v0.5.0, v0.4.0, v0.3.0, v0.1.0.
- Repo is **public**. Flatpak repo at <https://dexterlabs1.github.io/moonvibe/>,
  GPG-signed, and the Deck installs from it — so updates arrive in Discover.

## What was built this session

| Area | State |
|---|---|
| Local Linux builds in WSL2 | Working; `make -j32 release` ≈ 54 s |
| Flatpak build + signed repo + Discover updates | Working, verified end to end |
| Library: Continue row, capsules, section headers | Shipped in 0.4.0 |
| Host screen: status chips, real facts per machine | Shipped |
| Pairing: PIN in large tiles, host web-UI deep link | Shipped, verified against a real host |
| Menus and dialogs rebuilt on the design system | Shipped in 0.6.0 |
| Desktop-flash-on-launch fix | Shipped in 0.6.0 |
| In-stream drawer | On `main`, **unreleased and unverified over video** |
| Rebindable shortcuts (`app/settings/keybindings.*`) | On `main`; all chords settings-backed, defaults bit-for-bit; drawer on Select+L5; QML API ready, **no UI yet** |
| SettingsView redesign (SettingsSection + Mv* components) | On `main`; presentation-only (171 bindings / qsTr set identical); OSK bug fixed via press-to-edit field |
| Custom Qt Quick Controls style | Written, tracked, **does not work** — see notes. Superseded by hand-styling; do not retry without a new idea |

## Do these next, in this order

1. **Get the drawer verified over live video.** It is the feature that justifies
   the fork and it has never been seen running. Blocked on a host setting: the
   client gets `403 — lacks "Launch applications" permission`, granted per client
   in Vibepollo's Client Management. Until then use
   `MOONVIBE_DRAWER_PREVIEW=/tmp/d.bmp ./moonvibe`, which renders the panel and
   exits without needing a host or a stream.

2. **Make the drawer's controls actually do something.** Right now it renders and
   navigates but changes nothing: bitrate needs the Vibepollo ABR path (P3), and
   resolution/HDR need a soft reconnect that reuses pairing and restarts only
   RTSP/RTP.

3. **Shortcut-rebinding UI.** Backend done (`KeyBindings` QML singleton:
   `actions()`, `setBinding(id, str)` → "" or error, `resetOne`, `resetAll`;
   the gamepad chord is a 13th row flagged `gamepad: true`). Build the page as a
   `SettingsSection` in the new Settings using the Mv* components. Capture a
   chord by listening for the next key press, not by typing strings.

4. **Design debt from the review harness** — the first pass landed 2026-08-27
   (36 errors → 0; 427 warnings → 97). What is left is in BACKLOG.md under
   "Design debt": the library grid under the footer, library type off-ramp,
   scrim tokens, and stock `DialogButtonBox` buttons. `Theme.fsBody` is now 16
   (PRODUCT.md's floor); the ramp is [11, 13, 16, 22, 40].

5. **Cut 0.7.0** once the owner confirms Settings renders right (see
   "Verification" below). Release flow is manual: `~/verify.sh`-style flatpak
   build in WSL, sign with the key in `~/.gnupg-moonvibe`, push gh-pages, gh
   release. Every prior release in git history shows the exact commands.

6. **Keyboard-popup bug**: fixed on the Settings side (SteamGridDB field is
   press-to-edit; dialog fields no longer self-focus). If it still happens in the
   X → App options menu, that is a different cause — `PcView.qml`'s
   `renamePcDialog` still has `editText { focus: true }` (dialog-scoped, likely
   fine).

## Verification, the rule

Three layers, cheapest first. Do not skip to the last one for a question the
first can answer.

1. **`tools/shoot/review.sh`** — every screen captured offscreen (real binary,
   software rasteriser, frame grabbed in-process) plus the design linter. This
   is now the default way to see a change: it needs no display, no host, no
   owner, and it produces PNGs to read and a list of token/contrast/fit
   violations. Details in [CLAUDE.md](../CLAUDE.md#look-at-your-work-toolsshootreviewsh).
2. **WSLg by hand** — launch `./moonvibe` so the window lands on the owner's
   Windows desktop when something needs poking at live (input, focus travel,
   animation feel).
3. **The Flatpak on the Deck** — the only answer to "does it work", and the
   only artifact users get. Believe it over the local build.

The old rule said headless pixels lie. They did, because the harness screen-
scraped a window. It no longer does — but ASK THE OWNER WHAT THEY SEE remains
correct for anything about the real device: gamescope, HDR, controller feel.
Builders work in their own build dirs (`~/build/mv-*`) and never commit — Fable
reviews and commits by territory.

## Traps that will cost you time if you do not know them

- **Ask the user what they see.** A night was lost to a headless harness that
  reported black frames for a UI that rendered perfectly on the real desktop.
- **`pkill -f` matches your own shell.** Use `pkill -x` or kill by PID. This bit
  three times in one session despite already being documented.
- **Background apps die when the launching `wsl.exe` command ends.** Launch,
  interact and capture in a single command.
- **Bumping `app/version.txt` does not trigger a rebuild** — the generated
  Makefile has no dependency on it.
- **WSLg windows are Wayland**, so no Windows or X enumeration will find them.
- **Do not trust the local build over the Flatpak.** The Flatpak is what ships
  and what the user installs.

## Things only the user can decide or do

- Grant this client "Launch applications" permission on the host (blocks item 1).
- Whether the front door stays as the PC list. A home screen was built, shipped
  in 0.5.0 and removed in 0.6.0 at the user's request; `HomeView.qml` and
  `HomeModel` remain in the tree, unshipped, if it ever returns in another form.
- A SteamGridDB API key. Artwork enrichment is implemented and has never once
  executed.
- Whether publishing moves into CI. Today releases are built and signed by hand
  on the workstation, and the signing key exists in exactly one place:
  `~/.gnupg-moonvibe` in WSL, no passphrase, not backed up. If it is lost every
  client has to re-add the remote.
