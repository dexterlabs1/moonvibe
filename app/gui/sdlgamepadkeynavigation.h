#pragma once

#include <QTimer>
#include <QEvent>

#include "SDL_compat.h"

#include "settings/streamingpreferences.h"

class SdlGamepadKeyNavigation : public QObject
{
    Q_OBJECT

public:
    SdlGamepadKeyNavigation(StreamingPreferences* prefs);

    ~SdlGamepadKeyNavigation();

    Q_INVOKABLE void enable();

    Q_INVOKABLE void disable();

    Q_INVOKABLE void notifyWindowFocus(bool hasFocus);

    Q_INVOKABLE void setUiNavMode(bool settingsMode);

    Q_INVOKABLE int getConnectedGamepads();

private:
    // The four navigable directions, held on either the d-pad or the left
    // stick. Kept as a direction rather than a key so the actual key (arrows,
    // or Tab/Shift-Tab in settings' UI-nav mode) is resolved at emit time.
    enum NavDir { NavNone, NavUp, NavDown, NavLeft, NavRight };

    void sendKey(QEvent::Type type, Qt::Key key, Qt::KeyboardModifiers modifiers = Qt::NoModifier);

    void emitNavDirection(NavDir dir);

    void updateTimerState();

private slots:
    void onPollingTimerFired();

private:
    StreamingPreferences* m_Prefs;
    QTimer* m_PollingTimer;
    QList<SDL_GameController*> m_Gamepads;
    bool m_Enabled;
    bool m_UiNavMode;
    bool m_FirstPoll;
    bool m_HasFocus;
    // Held-direction auto-repeat. m_HeldDpadDir tracks the d-pad button held
    // right now (buttons don't auto-repeat, unlike the stick which we poll);
    // m_ActiveNavDir is the direction currently repeating from either source.
    NavDir m_HeldDpadDir;
    NavDir m_ActiveNavDir;
    Uint32 m_NavHoldStartTime;
    Uint32 m_LastNavRepeatTime;
};
