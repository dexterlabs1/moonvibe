#include "keybindings.h"
#include "utils.h"

#include <QSettings>
#include <QStringList>
#include <QVariantMap>

#define SER_KEYBINDINGS "keybindings"

namespace {

struct ActionDefault {
    KeyBindings::Action action;
    const char* id;
    const char* defaultBinding;

    // Some actions are pointless (or actively harmful) without a desktop
    // environment to hand the user back to, and were gated the same way when
    // this table was compiled into SdlInputHandler.
    bool requiresDesktopEnvironment;
};

// The defaults are the old hardcoded table, verbatim. Note that toggle_drawer
// and toggle_minimize both land on D: the drawer wins, because matching walks
// the actions in this order and the drawer comes first. That is exactly how the
// hardcoded table behaved once the drawer was added to it.
const ActionDefault k_ActionDefaults[] = {
    { KeyBindings::ActionQuit,                    "quit",                 "ctrl+alt+shift+q", false },
    { KeyBindings::ActionUngrabInput,             "ungrab_input",         "ctrl+alt+shift+z", true  },
    { KeyBindings::ActionToggleFullScreen,        "toggle_fullscreen",    "ctrl+alt+shift+x", true  },
    { KeyBindings::ActionToggleStatsOverlay,      "toggle_stats",         "ctrl+alt+shift+s", false },
    { KeyBindings::ActionToggleDrawer,            "toggle_drawer",        "ctrl+alt+shift+d", false },
    { KeyBindings::ActionToggleMouseMode,         "toggle_mouse_mode",    "ctrl+alt+shift+m", false },
    { KeyBindings::ActionToggleCursorHide,        "toggle_cursor_hide",   "ctrl+alt+shift+c", false },
    { KeyBindings::ActionToggleMinimize,          "toggle_minimize",      "ctrl+alt+shift+d", true  },
    { KeyBindings::ActionPasteText,               "paste_text",           "ctrl+alt+shift+v", false },
    { KeyBindings::ActionTogglePointerRegionLock, "toggle_pointer_lock",  "ctrl+alt+shift+l", false },
    { KeyBindings::ActionQuitAndExit,             "quit_and_exit",        "ctrl+alt+shift+e", false },
    { KeyBindings::ActionToggleKeyboardGrab,      "toggle_keyboard_grab", "ctrl+alt+shift+k", true  },
};

static_assert(SDL_arraysize(k_ActionDefaults) == KeyBindings::ActionMax,
              "Every action needs a default binding");

// Select + L5 on a Steam Deck.
const char* k_DefaultGamepadDrawerChord = "back+paddle1";

const char* k_GamepadDrawerActionId = "toggle_drawer_gamepad";

const char* k_UnboundToken = "none";

} // namespace

KeyBindings::KeyBindings(QObject* parent)
    : QObject(parent),
      m_DrawerGamepadChord(0),
      m_HasDesktopEnvironment(true)
{
    reload();
}

KeyBindings* KeyBindings::get()
{
    // Deliberately never destroyed: the input handler reads it during teardown
    // of a stream, and C++ guarantees this initialization is thread-safe.
    static KeyBindings* s_KeyBindings = new KeyBindings();
    return s_KeyBindings;
}

QString KeyBindings::actionId(Action action)
{
    Q_ASSERT(action >= 0 && action < ActionMax);
    return QString(k_ActionDefaults[action].id);
}

QString KeyBindings::defaultBindingString(Action action)
{
    Q_ASSERT(action >= 0 && action < ActionMax);
    return QString(k_ActionDefaults[action].defaultBinding);
}

QString KeyBindings::gamepadDrawerActionId()
{
    return QString(k_GamepadDrawerActionId);
}

QString KeyBindings::defaultGamepadDrawerChordString()
{
    return QString(k_DefaultGamepadDrawerChord);
}

QString KeyBindings::actionLabel(Action action)
{
    switch (action) {
    case ActionQuit:
        return tr("Quit stream");
    case ActionUngrabInput:
        return tr("Release mouse and keyboard");
    case ActionToggleFullScreen:
        return tr("Toggle full screen");
    case ActionToggleStatsOverlay:
        return tr("Toggle performance stats");
    case ActionToggleDrawer:
        return tr("Open the drawer");
    case ActionToggleMouseMode:
        return tr("Toggle mouse mode");
    case ActionToggleCursorHide:
        return tr("Show or hide the cursor");
    case ActionToggleMinimize:
        return tr("Minimize the window");
    case ActionPasteText:
        return tr("Type clipboard text");
    case ActionTogglePointerRegionLock:
        return tr("Lock the pointer to the video");
    case ActionQuitAndExit:
        return tr("Quit stream and close Moonvibe");
    case ActionToggleKeyboardGrab:
        return tr("Capture system keys");
    default:
        Q_UNREACHABLE();
        return QString();
    }
}

QString KeyBindings::gamepadDrawerActionLabel()
{
    return tr("Open the drawer (gamepad)");
}

bool KeyBindings::lookupAction(const QString& actionId, Action* action)
{
    for (int i = 0; i < ActionMax; i++) {
        if (actionId == QString(k_ActionDefaults[i].id)) {
            *action = (Action)i;
            return true;
        }
    }

    return false;
}

unsigned KeyBindings::modifiersFromSdl(quint16 sdlModifiers)
{
    unsigned modifiers = 0;

    if (sdlModifiers & KMOD_CTRL) {
        modifiers |= ModCtrl;
    }
    if (sdlModifiers & KMOD_ALT) {
        modifiers |= ModAlt;
    }
    if (sdlModifiers & KMOD_SHIFT) {
        modifiers |= ModShift;
    }
    if (sdlModifiers & KMOD_GUI) {
        modifiers |= ModGui;
    }

    return modifiers;
}

bool KeyBindings::modifiersMatch(unsigned required, unsigned held)
{
    // Ctrl, Alt and Shift must match exactly, so a binding on Ctrl+Alt+Shift+Q
    // does not also fire for Ctrl+Q, and one bound to Ctrl+Q does not fire when
    // the user is holding Shift for something else.
    const unsigned k_ExactMask = ModCtrl | ModAlt | ModShift;
    if ((required & k_ExactMask) != (held & k_ExactMask)) {
        return false;
    }

    // GUI is required only when the binding asks for it. The old code never
    // looked at it, so ignoring a stray Super press keeps the defaults behaving
    // bit-for-bit as they did.
    if ((required & ModGui) && !(held & ModGui)) {
        return false;
    }

    return true;
}

bool KeyBindings::parseBinding(const QString& text, Binding* binding, QString* error)
{
    Binding result;
    result.keyCode = SDLK_UNKNOWN;
    result.scanCode = SDL_SCANCODE_UNKNOWN;
    result.modifiers = 0;
    result.valid = false;

    auto fail = [error](const QString& message) -> bool {
        if (error != nullptr) {
            *error = message;
        }
        return false;
    };

    auto succeed = [binding, error, &result]() -> bool {
        if (binding != nullptr) {
            *binding = result;
        }
        if (error != nullptr) {
            error->clear();
        }
        return true;
    };

    QString trimmed = text.trimmed().toLower();
    if (trimmed.isEmpty()) {
        return fail(tr("Shortcut cannot be empty"));
    }

    // An explicitly unbound action. Parses fine; just never matches anything.
    if (trimmed == QString(k_UnboundToken)) {
        return succeed();
    }

    bool haveKey = false;
    const QStringList tokens = trimmed.split('+');
    for (const QString& rawToken : tokens) {
        QString token = rawToken.trimmed();

        if (token.isEmpty()) {
            return fail(tr("Shortcut has an empty part: \"%1\"").arg(text));
        }
        if (haveKey) {
            return fail(tr("The key must be the last part of a shortcut"));
        }

        if (token == "ctrl" || token == "control") {
            result.modifiers |= ModCtrl;
            continue;
        }
        if (token == "alt" || token == "option") {
            result.modifiers |= ModAlt;
            continue;
        }
        if (token == "shift") {
            result.modifiers |= ModShift;
            continue;
        }
        if (token == "gui" || token == "meta" || token == "super" ||
                token == "win" || token == "cmd") {
            result.modifiers |= ModGui;
            continue;
        }

        QByteArray name = token.toUtf8();
        SDL_Keycode keyCode = SDL_GetKeyFromName(name.constData());
        if (keyCode == SDLK_UNKNOWN) {
            return fail(tr("Unknown key: %1").arg(token));
        }

        result.keyCode = keyCode;

        // The scancode comes from the name rather than from the keycode on
        // purpose. SDL_GetScancodeFromKey() would resolve against the user's
        // current layout, but the scancode is our fallback for people whose
        // layout doesn't produce the keycode at all -- it has to stay the
        // physical position the key occupies on a US keyboard.
        result.scanCode = SDL_GetScancodeFromName(name.constData());

        haveKey = true;
    }

    if (!haveKey) {
        return fail(tr("Shortcut must include a key"));
    }

    result.valid = true;
    return succeed();
}

QString KeyBindings::serializeBinding(const Binding& binding)
{
    if (!binding.valid) {
        return QString(k_UnboundToken);
    }

    QStringList parts;

    if (binding.modifiers & ModCtrl) {
        parts.append(QStringLiteral("ctrl"));
    }
    if (binding.modifiers & ModAlt) {
        parts.append(QStringLiteral("alt"));
    }
    if (binding.modifiers & ModShift) {
        parts.append(QStringLiteral("shift"));
    }
    if (binding.modifiers & ModGui) {
        parts.append(QStringLiteral("gui"));
    }

    parts.append(QString(SDL_GetKeyName(binding.keyCode)).toLower());

    return parts.join('+');
}

bool KeyBindings::parseGamepadChord(const QString& text, quint32* chord, QString* error)
{
    auto fail = [error](const QString& message) -> bool {
        if (error != nullptr) {
            *error = message;
        }
        return false;
    };

    quint32 result = 0;
    QString trimmed = text.trimmed().toLower();

    if (!trimmed.isEmpty() && trimmed != QString(k_UnboundToken)) {
        const QStringList tokens = trimmed.split('+');
        for (const QString& rawToken : tokens) {
            QString token = rawToken.trimmed();

            if (token.isEmpty()) {
                return fail(tr("Gamepad chord has an empty part: \"%1\"").arg(text));
            }

            SDL_GameControllerButton button =
                    SDL_GameControllerGetButtonFromString(token.toUtf8().constData());
            if (button == SDL_CONTROLLER_BUTTON_INVALID) {
                return fail(tr("Unknown gamepad button: %1").arg(token));
            }

            result |= (1U << button);
        }
    }

    if (chord != nullptr) {
        *chord = result;
    }
    if (error != nullptr) {
        error->clear();
    }

    return true;
}

QString KeyBindings::serializeGamepadChord(quint32 chord)
{
    if (chord == 0) {
        return QString(k_UnboundToken);
    }

    QStringList parts;

    for (int i = 0; i < SDL_CONTROLLER_BUTTON_MAX; i++) {
        if (chord & (1U << i)) {
            const char* name = SDL_GameControllerGetStringForButton((SDL_GameControllerButton)i);
            parts.append(name != nullptr ? QString(name) : QString::number(i));
        }
    }

    return parts.join('+');
}

void KeyBindings::reload()
{
    QSettings settings;
    settings.beginGroup(SER_KEYBINDINGS);

    m_HasDesktopEnvironment = WMUtils::isRunningDesktopEnvironment();

    for (int i = 0; i < ActionMax; i++) {
        Action action = (Action)i;

        // The defaults table is indexed by Action, so it has to stay in order.
        Q_ASSERT(k_ActionDefaults[i].action == action);

        QString defaultText = defaultBindingString(action);
        QString text = settings.value(actionId(action), defaultText).toString();

        Binding binding;
        QString error;
        if (!parseBinding(text, &binding, &error)) {
            SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                        "Ignoring unusable binding for '%s' (\"%s\"): %s",
                        qPrintable(actionId(action)),
                        qPrintable(text),
                        qPrintable(error));

            // Fall back to the default, which always parses.
            text = defaultText;
            parseBinding(text, &binding, nullptr);
        }

        m_Bindings[i] = binding;
        m_BindingStrings[i] = text;
    }

    QString chordText = settings.value(gamepadDrawerActionId(),
                                       defaultGamepadDrawerChordString()).toString();
    quint32 chord;
    QString error;
    if (!parseGamepadChord(chordText, &chord, &error)) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Ignoring unusable gamepad chord for '%s' (\"%s\"): %s",
                    qPrintable(gamepadDrawerActionId()),
                    qPrintable(chordText),
                    qPrintable(error));

        chordText = defaultGamepadDrawerChordString();
        parseGamepadChord(chordText, &chord, nullptr);
    }

    m_DrawerGamepadChord = chord;
    m_DrawerGamepadChordString = chordText;
}

KeyBindings::Binding KeyBindings::binding(Action action) const
{
    Q_ASSERT(action >= 0 && action < ActionMax);
    return m_Bindings[action];
}

QString KeyBindings::bindingString(Action action) const
{
    Q_ASSERT(action >= 0 && action < ActionMax);
    return m_BindingStrings[action];
}

bool KeyBindings::isEnabled(Action action) const
{
    Q_ASSERT(action >= 0 && action < ActionMax);
    return m_HasDesktopEnvironment || !k_ActionDefaults[action].requiresDesktopEnvironment;
}

quint32 KeyBindings::drawerGamepadChord() const
{
    return m_DrawerGamepadChord;
}

QString KeyBindings::drawerGamepadChordString() const
{
    return m_DrawerGamepadChordString;
}

QVariantList KeyBindings::actions() const
{
    QVariantList list;

    for (int i = 0; i < ActionMax; i++) {
        Action action = (Action)i;

        QVariantMap entry;
        entry.insert("id", actionId(action));
        entry.insert("label", actionLabel(action));
        entry.insert("binding", m_BindingStrings[i]);
        entry.insert("defaultBinding", defaultBindingString(action));
        entry.insert("enabled", isEnabled(action));
        entry.insert("gamepad", false);

        list.append(entry);
    }

    QVariantMap gamepadEntry;
    gamepadEntry.insert("id", gamepadDrawerActionId());
    gamepadEntry.insert("label", gamepadDrawerActionLabel());
    gamepadEntry.insert("binding", m_DrawerGamepadChordString);
    gamepadEntry.insert("defaultBinding", defaultGamepadDrawerChordString());
    gamepadEntry.insert("enabled", true);
    gamepadEntry.insert("gamepad", true);

    list.append(gamepadEntry);

    return list;
}

void KeyBindings::writeSetting(const QString& key, const QString& value)
{
    QSettings settings;
    settings.beginGroup(SER_KEYBINDINGS);
    settings.setValue(key, value);
}

QString KeyBindings::setBinding(const QString& actionId, const QString& binding)
{
    QString error;

    if (actionId == gamepadDrawerActionId()) {
        quint32 chord;
        if (!parseGamepadChord(binding, &chord, &error)) {
            return error;
        }

        QString normalized = serializeGamepadChord(chord);
        writeSetting(actionId, normalized);

        m_DrawerGamepadChord = chord;
        m_DrawerGamepadChordString = normalized;

        emit bindingsChanged();
        return QString();
    }

    Action action;
    if (!lookupAction(actionId, &action)) {
        return tr("Unknown action: %1").arg(actionId);
    }

    Binding parsed;
    if (!parseBinding(binding, &parsed, &error)) {
        return error;
    }

    if (parsed.valid && (parsed.modifiers & (ModCtrl | ModAlt | ModShift | ModGui)) == 0) {
        // Legal, but it means every press of that key is eaten by us instead of
        // reaching the game. Worth a line in the log if it ever surprises someone.
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Binding '%s' to \"%s\" with no modifiers: the host will never see that key",
                    qPrintable(actionId),
                    qPrintable(binding));
    }

    QString normalized = serializeBinding(parsed);
    writeSetting(actionId, normalized);

    m_Bindings[action] = parsed;
    m_BindingStrings[action] = normalized;

    emit bindingsChanged();
    return QString();
}

void KeyBindings::resetOne(const QString& actionId)
{
    {
        QSettings settings;
        settings.beginGroup(SER_KEYBINDINGS);
        settings.remove(actionId);
    }

    reload();
    emit bindingsChanged();
}

void KeyBindings::resetAll()
{
    {
        QSettings settings;
        settings.beginGroup(SER_KEYBINDINGS);

        // Removing the empty key inside a group removes the whole group.
        settings.remove(QString());
    }

    reload();
    emit bindingsChanged();
}
