#pragma once

#include <QString>

class QQmlApplicationEngine;
class ComputerManager;

// Offscreen capture mode: renders one named UI state and exits.
//
// This exists because a UI you cannot see is a UI you cannot review, and every
// attempt to see this one through a screen (Xvfb, WSLg, window grabbers) has
// lied at least once -- see docs/ENGINEERING_NOTES.md. Shoot mode never goes
// near a display server. The scene is rendered by Qt Quick's software backend
// onto the offscreen platform plugin and grabbed in-process, so the PNG is the
// frame the scene graph produced, not a photograph of a window that may or may
// not exist.
//
// Alongside the PNG it writes a JSON dump of every visible item -- geometry,
// colors, fonts, and the background color sampled out of the rendered frame
// behind each piece of text. tools/shoot/designlint.py checks that dump against
// the Theme tokens, so "does this obey the design system" is answered by
// arithmetic instead of by eye.
//
//   MOONVIBE_SHOOT        name of the shot to render (activates this mode)
//   MOONVIBE_SHOOT_SCRIPT path to the shot definitions (default tools/shoot/shots.json)
//   MOONVIBE_SHOOT_OUT    output directory (default the working directory)
//
// Nothing here compiles out of the shipping binary on purpose: the mode a
// reviewer uses must be the same code a user runs, or it is reviewing a
// different program.
namespace ShootMode
{
    // True when MOONVIBE_SHOOT names a shot.
    bool active();

    // Loads the shot definition and points Qt, SDL and QStandardPaths somewhere
    // deterministic. MUST be called before the QGuiApplication is constructed --
    // the graphics backend and platform plugin cannot be changed afterwards.
    // Returns false if the shot could not be loaded; the caller should exit.
    bool prepareEnvironment();

    // The view main.qml should start on for this shot.
    QString initialView();

    // Fills a freshly constructed ComputerManager with hosts that do not exist,
    // so screens that need a host render fully without one. Also puts the
    // manager into fixture mode, which stops it polling or persisting them.
    void installFixtures(ComputerManager* manager);

    // Drives the shot: waits for the first frame, runs the shot's steps, grabs
    // the window, writes <name>.png and <name>.json, and quits the app. Call
    // once, after engine.load() has produced a window.
    void begin(QQmlApplicationEngine* engine);
}
