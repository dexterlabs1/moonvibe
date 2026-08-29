#include "sdlgamepadkeynavigation.h"

#include <QKeyEvent>
#include <QGuiApplication>
#include <QWindow>

#include "settings/mappingmanager.h"

// Held-direction auto-repeat. The first move fires the instant a direction is
// engaged; the direction then has to be held past the initial delay before it
// begins repeating, and the gap between repeats ramps from SLOW down to FAST
// the longer it is held, so a list scrolls off gently and then quickly.
#define NAV_REPEAT_INITIAL_DELAY 350
#define NAV_REPEAT_SLOW_INTERVAL 110
#define NAV_REPEAT_FAST_INTERVAL 45
#define NAV_REPEAT_ACCEL_TIME    1200

// How far the left stick must be pushed before it counts as a held direction.
#define STICK_NAV_THRESHOLD 24000

SdlGamepadKeyNavigation::SdlGamepadKeyNavigation(StreamingPreferences* prefs)
    : m_Prefs(prefs),
      m_Enabled(false),
      m_UiNavMode(false),
      m_FirstPoll(false),
      m_HasFocus(false),
      m_HeldDpadDir(NavNone),
      m_ActiveNavDir(NavNone),
      m_NavHoldStartTime(0),
      m_LastNavRepeatTime(0)
{
    m_PollingTimer = new QTimer(this);
    connect(m_PollingTimer, &QTimer::timeout, this, &SdlGamepadKeyNavigation::onPollingTimerFired);
}

SdlGamepadKeyNavigation::~SdlGamepadKeyNavigation()
{
    disable();
}

void SdlGamepadKeyNavigation::enable()
{
    if (m_Enabled) {
        return;
    }

    // We have to initialize and uninitialize this in enable()/disable()
    // because we need to get out of the way of the Session class. If it
    // doesn't get to reinitialize the GC subsystem, it won't get initial
    // arrival events. Additionally, there's a race condition between
    // our QML objects being destroyed and SDL being deinitialized that
    // this solves too.
    if (SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER) != 0) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER) failed: %s",
                     SDL_GetError());
        return;
    }

    MappingManager mappingManager;
    mappingManager.applyMappings();

    // Drop all pending gamepad add events. SDL will generate these for us
    // on first init of the GC subsystem. We can't depend on them due to
    // overlapping lifetimes of SdlGamepadKeyNavigation instances, so we
    // will attach ourselves.
    //
    // NB: We use SDL_JoystickUpdate() instead of SDL_PumpEvents() because
    // the latter can do a bit more work that we want (like handling video
    // events that we intentionally do not want to process yet).
    SDL_JoystickUpdate();
    SDL_FlushEvent(SDL_CONTROLLERDEVICEADDED);

    // Open all currently attached game controllers
    int numJoysticks = SDL_NumJoysticks();
    for (int i = 0; i < numJoysticks; i++) {
        if (SDL_IsGameController(i)) {
            SDL_GameController* gc = SDL_GameControllerOpen(i);
            if (gc != nullptr) {
                m_Gamepads.append(gc);
            }
        }
    }

    m_Enabled = true;

    // Start the polling timer if the window is focused
    updateTimerState();
}

void SdlGamepadKeyNavigation::disable()
{
    if (!m_Enabled) {
        return;
    }

    m_Enabled = false;
    updateTimerState();
    Q_ASSERT(!m_PollingTimer->isActive());

    while (!m_Gamepads.isEmpty()) {
        SDL_GameControllerClose(m_Gamepads[0]);
        m_Gamepads.removeAt(0);
    }

    SDL_QuitSubSystem(SDL_INIT_GAMECONTROLLER);
}

void SdlGamepadKeyNavigation::notifyWindowFocus(bool hasFocus)
{
    m_HasFocus = hasFocus;
    updateTimerState();
}

void SdlGamepadKeyNavigation::onPollingTimerFired()
{
    SDL_Event event;

    // Update joystick state without pumping other events (see enable() comment)
    SDL_JoystickUpdate();

    // Discard any pending button events on the first poll to avoid picking up
    // stale input data from the stream session (like the quit combo). A queued
    // SDL_QUIT is stale in the same way -- it belongs to whatever tore the video
    // subsystem down while we were not polling, not to the user.
    if (m_FirstPoll) {
        SDL_FlushEvent(SDL_CONTROLLERBUTTONDOWN);
        SDL_FlushEvent(SDL_CONTROLLERBUTTONUP);
        SDL_FlushEvent(SDL_QUIT);
        // Drop any held-direction state carried over from a previous enable.
        m_HeldDpadDir = NavNone;
        m_ActiveNavDir = NavNone;
        m_FirstPoll = false;
    }

    // SDL posts a quit event because we hold the video subsystem open on
    // startup, and posts another every time it is torn down -- which
    // SystemProperties' decoder probe does on its own schedule, seconds after
    // launch. In GUI mode there is no SDL window: the shell is a Qt
    // ApplicationWindow, so the real quit paths are its close button and B on
    // the host list (both go through quitConfirmationDialog), and this poller
    // is disabled the whole time a stream owns the SDL window. Every SDL_QUIT
    // we could see here is therefore that spurious teardown event, never the
    // user. Acting on it made the app exit by itself (upstream) or pop an
    // unbidden quit prompt (worse). Swallow it.
    SDL_FlushEvent(SDL_QUIT);

    // Peep events rather than polling to avoid calling SDL_PumpEvents(), and
    // take only the controller range: anything else in the queue belongs to
    // another part of the app and has to stay there for it to find.
    while (SDL_PeepEvents(&event, 1, SDL_GETEVENT,
                          SDL_CONTROLLERAXISMOTION, SDL_CONTROLLERDEVICEREMAPPED) == 1) {
        switch (event.type) {
        case SDL_CONTROLLERBUTTONDOWN:
        case SDL_CONTROLLERBUTTONUP:
        {
            QEvent::Type type =
                    event.type == SDL_CONTROLLERBUTTONDOWN ?
                        QEvent::Type::KeyPress : QEvent::Type::KeyRelease;

            // Swap face buttons if needed
            if (m_Prefs->swapFaceButtons) {
                switch (event.cbutton.button) {
                case SDL_CONTROLLER_BUTTON_A:
                    event.cbutton.button = SDL_CONTROLLER_BUTTON_B;
                    break;
                case SDL_CONTROLLER_BUTTON_B:
                    event.cbutton.button = SDL_CONTROLLER_BUTTON_A;
                    break;
                case SDL_CONTROLLER_BUTTON_X:
                    event.cbutton.button = SDL_CONTROLLER_BUTTON_Y;
                    break;
                case SDL_CONTROLLER_BUTTON_Y:
                    event.cbutton.button = SDL_CONTROLLER_BUTTON_X;
                    break;
                }
            }

            switch (event.cbutton.button) {
            // The four directions are not sent from here. They register a held
            // direction that the auto-repeat block below drives, so holding the
            // d-pad scrolls continuously instead of moving one step per press.
            // On release, only clear the direction if it is still the held one.
            case SDL_CONTROLLER_BUTTON_DPAD_UP:
                m_HeldDpadDir = (type == QEvent::Type::KeyPress) ? NavUp
                              : (m_HeldDpadDir == NavUp ? NavNone : m_HeldDpadDir);
                break;
            case SDL_CONTROLLER_BUTTON_DPAD_DOWN:
                m_HeldDpadDir = (type == QEvent::Type::KeyPress) ? NavDown
                              : (m_HeldDpadDir == NavDown ? NavNone : m_HeldDpadDir);
                break;
            case SDL_CONTROLLER_BUTTON_DPAD_LEFT:
                m_HeldDpadDir = (type == QEvent::Type::KeyPress) ? NavLeft
                              : (m_HeldDpadDir == NavLeft ? NavNone : m_HeldDpadDir);
                break;
            case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
                m_HeldDpadDir = (type == QEvent::Type::KeyPress) ? NavRight
                              : (m_HeldDpadDir == NavRight ? NavNone : m_HeldDpadDir);
                break;
            case SDL_CONTROLLER_BUTTON_A:
                if (m_UiNavMode) {
                    sendKey(type, Qt::Key_Space);
                }
                else {
                    sendKey(type, Qt::Key_Return);
                }
                break;
            case SDL_CONTROLLER_BUTTON_B:
                sendKey(type, Qt::Key_Escape);
                break;
            case SDL_CONTROLLER_BUTTON_X:
                sendKey(type, Qt::Key_Menu);
                break;
            case SDL_CONTROLLER_BUTTON_Y:
            case SDL_CONTROLLER_BUTTON_START:
                // HACK: We use this keycode to inform main.qml
                // to show the settings when Key_Menu is handled
                // by the control in focus.
                sendKey(type, Qt::Key_Hangup);
                break;
            default:
                break;
            }
            break;
        }
        case SDL_CONTROLLERDEVICEADDED:
            SDL_GameController* gc = SDL_GameControllerOpen(event.cdevice.which);
            if (gc != nullptr) {
                // SDL_CONTROLLERDEVICEADDED can be reported multiple times for the same
                // gamepad in rare cases, because SDL doesn't fixup the device index in
                // the SDL_CONTROLLERDEVICEADDED event if an unopened gamepad disappears
                // before we've processed the add event.
                if (!m_Gamepads.contains(gc)) {
                    m_Gamepads.append(gc);
                }
                else {
                    // We already have this game controller open
                    SDL_GameControllerClose(gc);
                }
            }
            break;
        }
    }

    // The left stick, polled, is the other source of a held direction.
    NavDir stickDir = NavNone;
    for (auto gc : std::as_const(m_Gamepads)) {
        short leftX = SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_LEFTX);
        short leftY = SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_LEFTY);
        if (leftY < -STICK_NAV_THRESHOLD) { stickDir = NavUp; break; }
        else if (leftY > STICK_NAV_THRESHOLD) { stickDir = NavDown; break; }
        else if (leftX < -STICK_NAV_THRESHOLD) { stickDir = NavLeft; break; }
        else if (leftX > STICK_NAV_THRESHOLD) { stickDir = NavRight; break; }
    }

    // The d-pad wins over the stick when both are engaged.
    NavDir dir = (m_HeldDpadDir != NavNone) ? m_HeldDpadDir : stickDir;
    Uint32 now = SDL_GetTicks();

    if (dir == NavNone) {
        // Nothing held -- next engage starts fresh.
        m_ActiveNavDir = NavNone;
    }
    else if (dir != m_ActiveNavDir) {
        // Newly engaged, or switched direction: move once immediately, then
        // wait out the initial delay before auto-repeat kicks in.
        emitNavDirection(dir);
        m_ActiveNavDir = dir;
        m_NavHoldStartTime = now;
        m_LastNavRepeatTime = now;
    }
    else {
        // Same direction still held. Repeat once the initial delay has passed,
        // at an interval that accelerates from SLOW toward FAST.
        Uint32 heldFor = now - m_NavHoldStartTime;
        if (heldFor >= NAV_REPEAT_INITIAL_DELAY) {
            Uint32 repeatFor = heldFor - NAV_REPEAT_INITIAL_DELAY;
            Uint32 interval = (repeatFor >= NAV_REPEAT_ACCEL_TIME)
                    ? NAV_REPEAT_FAST_INTERVAL
                    : NAV_REPEAT_SLOW_INTERVAL -
                          (NAV_REPEAT_SLOW_INTERVAL - NAV_REPEAT_FAST_INTERVAL)
                          * repeatFor / NAV_REPEAT_ACCEL_TIME;
            if (now - m_LastNavRepeatTime >= interval) {
                emitNavDirection(dir);
                m_LastNavRepeatTime = now;
            }
        }
    }
}

void SdlGamepadKeyNavigation::emitNavDirection(NavDir dir)
{
    switch (dir) {
    case NavUp:
        if (m_UiNavMode) {
            // Back-tab
            sendKey(QEvent::Type::KeyPress, Qt::Key_Tab, Qt::ShiftModifier);
            sendKey(QEvent::Type::KeyRelease, Qt::Key_Tab, Qt::ShiftModifier);
        }
        else {
            sendKey(QEvent::Type::KeyPress, Qt::Key_Up);
            sendKey(QEvent::Type::KeyRelease, Qt::Key_Up);
        }
        break;
    case NavDown:
        if (m_UiNavMode) {
            sendKey(QEvent::Type::KeyPress, Qt::Key_Tab);
            sendKey(QEvent::Type::KeyRelease, Qt::Key_Tab);
        }
        else {
            sendKey(QEvent::Type::KeyPress, Qt::Key_Down);
            sendKey(QEvent::Type::KeyRelease, Qt::Key_Down);
        }
        break;
    case NavLeft:
        sendKey(QEvent::Type::KeyPress, Qt::Key_Left);
        sendKey(QEvent::Type::KeyRelease, Qt::Key_Left);
        break;
    case NavRight:
        sendKey(QEvent::Type::KeyPress, Qt::Key_Right);
        sendKey(QEvent::Type::KeyRelease, Qt::Key_Right);
        break;
    default:
        break;
    }
}

void SdlGamepadKeyNavigation::sendKey(QEvent::Type type, Qt::Key key, Qt::KeyboardModifiers modifiers)
{
    QGuiApplication* app = static_cast<QGuiApplication*>(QGuiApplication::instance());
    QWindow* focusWindow = app->focusWindow();
    if (focusWindow != nullptr) {
        QKeyEvent keyPressEvent(type, key, modifiers);
        app->sendEvent(focusWindow, &keyPressEvent);
    }
}

void SdlGamepadKeyNavigation::updateTimerState()
{
    if (m_PollingTimer->isActive() && (!m_HasFocus || !m_Enabled)) {
        m_PollingTimer->stop();
    }
    else if (!m_PollingTimer->isActive() && m_HasFocus && m_Enabled) {
        // Flush events on the first poll
        m_FirstPoll = true;

        // Poll every 50 ms for a new joystick event
        m_PollingTimer->start(50);
    }
}

void SdlGamepadKeyNavigation::setUiNavMode(bool uiNavMode)
{
    m_UiNavMode = uiNavMode;
}

int SdlGamepadKeyNavigation::getConnectedGamepads()
{
    Q_ASSERT(m_Enabled);

    int count = 0;
    int numJoysticks = SDL_NumJoysticks();
    for (int i = 0; i < numJoysticks; i++) {
        if (SDL_IsGameController(i)) {
            count++;
        }
    }

    return count;
}
