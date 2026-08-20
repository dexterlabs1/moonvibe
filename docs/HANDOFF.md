# Handoff — 2026-08-20

State of Moonvibe at the end of the Opus session, for whoever picks this up next.
Read [ENGINEERING_NOTES.md](ENGINEERING_NOTES.md) first if anything below looks
surprising — the traps are recorded there.

## Where things stand

- `main` is pushed and clean. Working tree has no uncommitted changes.
- **The Deck runs 0.6.0.** Everything after that (the in-stream drawer) is on
  `main` but unreleased.
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
| Custom Qt Quick Controls style | Written, tracked, **does not work** — see notes |

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

3. **Rebindable shortcuts.** The user asked for this directly. The drawer toggle
   is currently `Ctrl+Alt+Shift+D`, a placeholder — it belongs on Select+L5 on a
   Deck. Do not hardcode a gamepad chord; build the bindings store first, then
   express the drawer toggle through it. Quit is hardcoded today too.

4. **SettingsView.** 1800 lines of stock Qt and the biggest remaining surface
   that still reads as moonlight. Hand-style it (custom section/checkbox/combo
   components) rather than waiting on the global style.

5. **The keyboard-on-app-options bug** the user reported, still unreproduced. Two
   things would pin it down: does it happen in Desktop Mode as well as Gaming
   Mode, and is it the X → App options menu or the gear/Settings screen? If it is
   Settings, the SteamGridDB API key `TextField` added to Host Settings is the
   likely cause and should not take focus.

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
