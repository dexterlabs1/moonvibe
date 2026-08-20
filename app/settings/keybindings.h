#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>

#include "SDL_compat.h"

// Rebindable in-stream shortcuts.
//
// Everything the client itself reacts to during a stream -- quit, the drawer,
// the stats overlay -- resolves through here instead of a table compiled into
// SdlInputHandler. Bindings are stored under the "keybindings" group in
// QSettings as strings a human can read and type ("ctrl+alt+shift+q"), and the
// defaults reproduce the old hardcoded table exactly, so an install with no
// settings behaves precisely as it did before.
class KeyBindings : public QObject
{
    Q_OBJECT

public:
    // One id per special key combo. The order matches SdlInputHandler::KeyCombo,
    // but nothing relies on that -- the mapping is spelled out in input.cpp.
    enum Action {
        ActionQuit,
        ActionUngrabInput,
        ActionToggleFullScreen,
        ActionToggleStatsOverlay,
        ActionToggleDrawer,
        ActionToggleMouseMode,
        ActionToggleCursorHide,
        ActionToggleMinimize,
        ActionPasteText,
        ActionTogglePointerRegionLock,
        ActionQuitAndExit,
        ActionToggleKeyboardGrab,
        ActionMax
    };
    Q_ENUM(Action)

    // Modifier bits. Left and right modifiers are the same thing to us.
    enum Modifier {
        ModCtrl  = 0x1,
        ModAlt   = 0x2,
        ModShift = 0x4,
        ModGui   = 0x8,
    };
    Q_ENUM(Modifier)

    struct Binding {
        SDL_Keycode keyCode;
        SDL_Scancode scanCode;
        unsigned modifiers;

        // False for a deliberately unbound action ("none") as well as for a
        // string we could not make sense of.
        bool valid;
    };

    static KeyBindings* get();

    // Re-reads every binding from QSettings.
    void reload();

    Binding binding(Action action) const;

    QString bindingString(Action action) const;

    // Whether this action is available at all in the current environment.
    // A few of them only make sense when there is a desktop to return to.
    bool isEnabled(Action action) const;

    // The gamepad chord that toggles the drawer, as a bitmask of
    // (1 << SDL_GameControllerButton) values. Zero means unbound.
    quint32 drawerGamepadChord() const;

    QString drawerGamepadChordString() const;

    static QString actionId(Action action);
    static QString actionLabel(Action action);
    static QString defaultBindingString(Action action);

    // The gamepad drawer chord rides the same id-based API as the keyboard
    // bindings so one settings page can present all of them together.
    static QString gamepadDrawerActionId();
    static QString gamepadDrawerActionLabel();
    static QString defaultGamepadDrawerChordString();

    // Keyboard chord: ordered modifier tokens then exactly one key token, named
    // the way SDL names it ("ctrl+alt+shift+d", "shift+f13", "left"). "none"
    // parses successfully into an unbound binding.
    static bool parseBinding(const QString& text, Binding* binding, QString* error);
    static QString serializeBinding(const Binding& binding);

    // Gamepad chord, using SDL's own button names: "back+paddle1". "none" and
    // the empty string parse into an unbound (zero) chord.
    static bool parseGamepadChord(const QString& text, quint32* chord, QString* error);
    static QString serializeGamepadChord(quint32 chord);

    // Collapses an SDL keysym modifier mask down to our Modifier bits.
    static unsigned modifiersFromSdl(quint16 sdlModifiers);

    // Does the currently held modifier mask satisfy what a binding asks for?
    static bool modifiersMatch(unsigned required, unsigned held);

    // QML-facing API for a future settings page.
    Q_INVOKABLE QVariantList actions() const;
    Q_INVOKABLE QString setBinding(const QString& actionId, const QString& binding);
    Q_INVOKABLE void resetAll();
    Q_INVOKABLE void resetOne(const QString& actionId);

signals:
    void bindingsChanged();

private:
    explicit KeyBindings(QObject* parent = nullptr);

    static bool lookupAction(const QString& actionId, Action* action);

    void writeSetting(const QString& key, const QString& value);

    Binding m_Bindings[ActionMax];
    QString m_BindingStrings[ActionMax];
    quint32 m_DrawerGamepadChord;
    QString m_DrawerGamepadChordString;
    bool m_HasDesktopEnvironment;
};
