#include "shootmode.h"
#include "scenedump.h"

#include "backend/computermanager.h"
#include "backend/nvcomputer.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QKeySequence>
#include <QMouseEvent>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlExpression>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QSettings>
#include <QTimer>
#include <QtDebug>

#ifdef Q_OS_UNIX
#include <csignal>
#include <execinfo.h>
#include <unistd.h>
#endif

namespace
{

struct Step
{
    QString key;    // a QKeySequence string: "Down", "Return", "Ctrl+Tab"
    QString eval;   // a QML expression evaluated in main.qml's scope
    QPointF click{-1, -1};
    int waitMs = 150;
};

struct Shot
{
    QString name;
    QString view = QStringLiteral("qrc:/gui/PcView.qml");
    QString fixtures = QStringLiteral("default");
    int width = 1280;
    int height = 800;
    int settleMs = 500;
    int timeoutMs = 20000;
    QVector<Step> steps;
    // Extra environment set before the app reads it, so a shot can pin things
    // that are decided once at startup -- e.g. HAS_DESKTOP_ENVIRONMENT and
    // MOONVIBE_GAMING for the Gaming-Mode gating, which SystemProperties reads
    // in its constructor.
    QVector<QPair<QByteArray, QByteArray>> env;
    bool valid = false;
};

Shot s_Shot;
QString s_OutDir;
QQuickWindow* s_Window = nullptr;
bool s_Started = false;
bool s_Captured = false;

// Milestones on stderr. A shot that dies has to say how far it got: the whole
// point of this harness is that a silent failure never again gets mistaken for
// a broken UI.
void trace(const QString& message)
{
    fprintf(stderr, "shoot[%s]: %s\n", qPrintable(s_Shot.name), qPrintable(message));
    fflush(stderr);
}

#ifdef Q_OS_UNIX
// A shot that dies takes its stack with it unless someone asks. Addresses are
// enough: addr2line -e app/moonvibe <addr> turns them into lines.
void crashHandler(int signalNumber)
{
    void* frames[64];
    int count = backtrace(frames, 64);

    fprintf(stderr, "shoot: fatal signal %d\n", signalNumber);
    fflush(stderr);
    backtrace_symbols_fd(frames, count, STDERR_FILENO);

    _exit(128 + signalNumber);
}
#endif

void finish(int code, const QString& message)
{
    if (!message.isEmpty()) {
        fprintf(stderr, "shoot[%s]: %s\n", qPrintable(s_Shot.name), qPrintable(message));
    }
    fflush(stderr);
    QCoreApplication::exit(code);
}

Shot parseShot(const QJsonObject& object, const QString& name)
{
    Shot shot;
    shot.name = name;
    shot.valid = true;

    if (object.contains("view")) {
        shot.view = object["view"].toString();
    }
    if (object.contains("fixtures")) {
        shot.fixtures = object["fixtures"].toString();
    }
    if (object.contains("width")) {
        shot.width = object["width"].toInt();
    }
    if (object.contains("height")) {
        shot.height = object["height"].toInt();
    }
    if (object.contains("settleMs")) {
        shot.settleMs = object["settleMs"].toInt();
    }
    if (object.contains("timeoutMs")) {
        shot.timeoutMs = object["timeoutMs"].toInt();
    }
    if (object.contains("env")) {
        const QJsonObject env = object["env"].toObject();
        for (auto it = env.begin(); it != env.end(); ++it) {
            shot.env.append({ it.key().toLocal8Bit(), it.value().toString().toLocal8Bit() });
        }
    }

    const QJsonArray steps = object["steps"].toArray();
    for (const QJsonValue& value : steps) {
        const QJsonObject stepObject = value.toObject();
        Step step;
        step.key = stepObject["key"].toString();
        step.eval = stepObject["eval"].toString();
        if (stepObject.contains("click")) {
            const QJsonArray point = stepObject["click"].toArray();
            step.click = QPointF(point.at(0).toDouble(), point.at(1).toDouble());
        }
        if (stepObject.contains("waitMs")) {
            step.waitMs = stepObject["waitMs"].toInt();
        }
        shot.steps.append(step);
    }

    return shot;
}

bool loadShot()
{
    const QString name = QString::fromLocal8Bit(qgetenv("MOONVIBE_SHOOT"));

    QString scriptPath = QString::fromLocal8Bit(qgetenv("MOONVIBE_SHOOT_SCRIPT"));
    if (scriptPath.isEmpty()) {
        scriptPath = QStringLiteral("tools/shoot/shots.json");
    }

    QFile file(scriptPath);
    if (!file.open(QIODevice::ReadOnly)) {
        fprintf(stderr, "shoot: cannot read %s\n", qPrintable(scriptPath));
        return false;
    }

    QJsonParseError error{};
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &error);
    if (document.isNull()) {
        fprintf(stderr, "shoot: %s is not valid JSON: %s\n",
                qPrintable(scriptPath), qPrintable(error.errorString()));
        return false;
    }

    const QJsonObject shots = document.object()["shots"].toObject();
    if (!shots.contains(name)) {
        fprintf(stderr, "shoot: no shot named '%s' in %s. Known shots: %s\n",
                qPrintable(name), qPrintable(scriptPath),
                qPrintable(shots.keys().join(QStringLiteral(", "))));
        return false;
    }

    s_Shot = parseShot(shots[name].toObject(), name);
    return true;
}

// Hosts that do not exist, described exactly enough that every chip, badge and
// empty state on the host screen has something real to render.
QVector<NvComputer*> buildFixtures(const QString& variant)
{
    QVector<NvComputer*> hosts;

    if (variant == QLatin1String("none")) {
        return hosts;
    }

    auto* tower = new NvComputer();
    tower->name = QStringLiteral("TOWER");
    tower->uuid = QStringLiteral("00000000-0000-0000-0000-00000000t0wr");
    tower->state = NvComputer::CS_ONLINE;
    tower->pairState = NvComputer::PS_PAIRED;
    tower->activeAddress = NvAddress(QStringLiteral("10.0.0.12"), 47989);
    tower->localAddress = tower->activeAddress;
    tower->activeHttpsPort = 47984;
    tower->gpuModel = QStringLiteral("NVIDIA GeForce RTX 5090");
    tower->appVersion = QStringLiteral("7.1.431.0");
    tower->isSupportedServerVersion = true;
    tower->isNvidiaServerSoftware = false;
    tower->maxLumaPixelsHEVC = 1;
    tower->serverCodecModeSupport = 0x21;
    tower->displayModes = { {3840, 2160, 120}, {2560, 1440, 120}, {1920, 1080, 60} };
    tower->currentGameId = 0;

    struct FixtureApp
    {
        int id;
        const char* name;
        bool hdr;
        int hoursAgo;   // -1 = never played
    };

    // Long names, short names, punctuation and an unplayed title, because those
    // are the cases that break a capsule grid.
    static const FixtureApp apps[] = {
        { 101, "Hollow Knight: Silksong",   false,  3 },
        { 102, "ELDEN RING",                true,  27 },
        { 103, "Deep Rock Galactic",        false,  9 },
        { 104, "Balatro",                   false,  1 },
        { 105, "Cyber Courier",             true,  50 },
        { 106, "Vampire Survivors",         false, -1 },
        { 107, "Steam Big Picture",         true,  -1 },
        { 108, "Half-Life: Alyx",           true,  96 },
        { 109, "Tunic",                     false, -1 },
    };

    QVector<NvApp> appList;
    for (const FixtureApp& fixture : apps) {
        NvApp app;
        app.id = fixture.id;
        app.name = QString::fromUtf8(fixture.name);
        app.hdrSupported = fixture.hdr;
        app.isAppCollectorGame = false;
        app.hidden = false;
        // Never a direct-launch app: the host screen starts one immediately when
        // it is the only paired host, and the shot captures a stream segue
        // instead of the library.
        app.directLaunch = false;
        appList.append(app);

        if (fixture.hoursAgo >= 0) {
            // Written straight into settings rather than through
            // RecentApps::recordLaunch(), which can only stamp "now" -- the
            // Continue row is only worth looking at with a spread of ages.
            QSettings settings;
            settings.setValue(QStringLiteral("recentapps/%1/%2").arg(tower->uuid).arg(app.id),
                              QDateTime::currentMSecsSinceEpoch() - qint64(fixture.hoursAgo) * 3600000LL);
        }
    }
    tower->appList = appList;

    hosts.append(tower);

    if (variant == QLatin1String("single")) {
        return hosts;
    }

    // A host that is off, so the offline card and the Wake action have a subject.
    auto* couch = new NvComputer();
    couch->name = QStringLiteral("COUCH-PC");
    couch->uuid = QStringLiteral("00000000-0000-0000-0000-000000c0uch");
    couch->state = NvComputer::CS_OFFLINE;
    couch->pairState = NvComputer::PS_PAIRED;
    couch->localAddress = NvAddress(QStringLiteral("10.0.0.31"), 47989);
    couch->macAddress = QByteArray::fromHex("aabbccddeeff");
    couch->gpuModel = QStringLiteral("AMD Radeon RX 7800 XT");
    couch->isSupportedServerVersion = true;
    hosts.append(couch);

    // A host seen on the network but never paired.
    auto* studio = new NvComputer();
    studio->name = QStringLiteral("STUDIO-MINI");
    studio->uuid = QStringLiteral("00000000-0000-0000-0000-0000005tud1");
    studio->state = NvComputer::CS_ONLINE;
    studio->pairState = NvComputer::PS_NOT_PAIRED;
    studio->activeAddress = NvAddress(QStringLiteral("10.0.0.44"), 47989);
    studio->localAddress = studio->activeAddress;
    studio->gpuModel = QStringLiteral("Apple M4 Pro");
    studio->isSupportedServerVersion = true;
    hosts.append(studio);

    return hosts;
}

void sendKey(QQuickWindow* window, const QString& sequence)
{
    const QKeySequence parsed = QKeySequence::fromString(sequence);
    if (parsed.isEmpty()) {
        fprintf(stderr, "shoot: unrecognised key '%s'\n", qPrintable(sequence));
        return;
    }

    const QKeyCombination combination = parsed[0];
    const int key = combination.key();
    const Qt::KeyboardModifiers modifiers = combination.keyboardModifiers();

    QString text;
    if (key == Qt::Key_Return || key == Qt::Key_Enter) {
        text = QStringLiteral("\r");
    }
    else if (key >= Qt::Key_Space && key <= Qt::Key_AsciiTilde) {
        text = QChar(static_cast<char16_t>(key)).toLower();
    }

    QKeyEvent press(QEvent::KeyPress, key, modifiers, text);
    QCoreApplication::sendEvent(window, &press);

    QKeyEvent release(QEvent::KeyRelease, key, modifiers, text);
    QCoreApplication::sendEvent(window, &release);
}

void sendClick(QQuickWindow* window, const QPointF& point)
{
    QMouseEvent press(QEvent::MouseButtonPress, point, point, point,
                      Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
    QCoreApplication::sendEvent(window, &press);

    QMouseEvent release(QEvent::MouseButtonRelease, point, point, point,
                        Qt::LeftButton, Qt::NoButton, Qt::NoModifier);
    QCoreApplication::sendEvent(window, &release);
}

void evaluate(QObject* root, const QString& expression)
{
    // Evaluated in main.qml's own context, so ids declared there -- stackView,
    // settingsButton -- resolve exactly as they do inside the file.
    QQmlExpression qmlExpression(qmlContext(root), root, expression);
    qmlExpression.evaluate();

    if (qmlExpression.hasError()) {
        fprintf(stderr, "shoot: eval '%s' failed: %s\n",
                qPrintable(expression),
                qPrintable(qmlExpression.error().toString()));
    }
}

void capture()
{
    if (s_Captured) {
        return;
    }
    s_Captured = true;

    trace(QStringLiteral("grabbing"));

    const QImage frame = s_Window->grabWindow();
    if (frame.isNull()) {
        finish(4, "grabWindow() returned nothing");
        return;
    }

    QDir().mkpath(s_OutDir);

    const QString pngPath = QStringLiteral("%1/%2.png").arg(s_OutDir, s_Shot.name);
    if (!frame.save(pngPath)) {
        finish(4, QStringLiteral("could not write %1").arg(pngPath));
        return;
    }

    QJsonObject dump = SceneDump::dump(s_Window->contentItem(), frame);
    dump["shot"] = s_Shot.name;
    dump["view"] = s_Shot.view;
    dump["fixtures"] = s_Shot.fixtures;

    const QString jsonPath = QStringLiteral("%1/%2.json").arg(s_OutDir, s_Shot.name);
    QFile jsonFile(jsonPath);
    if (!jsonFile.open(QIODevice::WriteOnly)) {
        finish(4, QStringLiteral("could not write %1").arg(jsonPath));
        return;
    }
    jsonFile.write(QJsonDocument(dump).toJson(QJsonDocument::Indented));
    jsonFile.close();

    finish(0, QStringLiteral("wrote %1 (%2x%3) and %4")
               .arg(pngPath).arg(frame.width()).arg(frame.height()).arg(jsonPath));
}

void runStep(QQmlApplicationEngine* engine, QObject* root, int index)
{
    if (index >= s_Shot.steps.size()) {
        QTimer::singleShot(s_Shot.settleMs, qApp, capture);
        return;
    }

    const Step& step = s_Shot.steps.at(index);
    trace(QStringLiteral("step %1/%2").arg(index + 1).arg(s_Shot.steps.size()));

    if (!step.eval.isEmpty()) {
        evaluate(root, step.eval);
    }
    if (!step.key.isEmpty()) {
        sendKey(s_Window, step.key);
    }
    if (step.click.x() >= 0) {
        sendClick(s_Window, step.click);
    }

    QTimer::singleShot(step.waitMs, qApp, [engine, root, index]() {
        runStep(engine, root, index + 1);
    });
}

} // namespace

bool ShootMode::active()
{
    return qEnvironmentVariableIsSet("MOONVIBE_SHOOT") &&
           !qgetenv("MOONVIBE_SHOOT").isEmpty();
}

bool ShootMode::prepareEnvironment()
{
    if (!loadShot()) {
        return false;
    }

#ifdef Q_OS_UNIX
    signal(SIGSEGV, crashHandler);
    signal(SIGABRT, crashHandler);
#endif

    // Apply the shot's own environment first, before anything reads it. A shot
    // may deliberately override values the harness sets below (or that
    // SystemProperties reads at startup), so this comes early.
    for (const auto& entry : s_Shot.env) {
        qputenv(entry.first.constData(), entry.second);
    }

    s_OutDir = QString::fromLocal8Bit(qgetenv("MOONVIBE_SHOOT_OUT"));
    if (s_OutDir.isEmpty()) {
        s_OutDir = QStringLiteral(".");
    }

    // No display server anywhere in the path. The frame is produced by the
    // software rasteriser and read back from memory, which is why this harness
    // can be trusted where screen-scraping ones could not.
    // The software rasteriser is the point: no GPU, no driver, no compositor,
    // and a frame that can be read straight back out of memory.
    if (qgetenv("MOONVIBE_SHOOT_BACKEND") != "gl") {
        QQuickWindow::setGraphicsApi(QSGRendererInterface::Software);
    }
    if (!qEnvironmentVariableIsSet("MOONVIBE_SHOOT_KEEP_PLATFORM")) {
        qputenv("QT_QPA_PLATFORM", "offscreen");
    }
    qputenv("SDL_VIDEODRIVER", "dummy");
    qputenv("QT_SCALE_FACTOR", "1");
    qputenv("QT_ENABLE_HIGHDPI_SCALING", "0");
    qputenv("QML_DISABLE_DISK_CACHE", "1");

    // Settings, box art and logs go to a scratch directory: a review run must
    // not read the developer's paired hosts and must never write fake ones into
    // their config.
    //
    // Wiped per shot, and named per shot, because the app writes as it runs --
    // a launch recorded by one shot turned up in the next one's Continue row.
    // A capture that depends on what ran before it is not a fixture, it is a
    // souvenir.
    const QString stateDir = QStringLiteral("%1/state/%2").arg(s_OutDir, s_Shot.name);
    QDir(stateDir).removeRecursively();
    QDir().mkpath(stateDir);
    const QByteArray state = stateDir.toLocal8Bit();
    qputenv("XDG_CONFIG_HOME", state + "/config");
    qputenv("XDG_CACHE_HOME", state + "/cache");
    qputenv("XDG_DATA_HOME", state + "/data");

    trace(QStringLiteral("prepared: view=%1 fixtures=%2 %3x%4 out=%5")
              .arg(s_Shot.view, s_Shot.fixtures)
              .arg(s_Shot.width).arg(s_Shot.height).arg(s_OutDir));
    return true;
}

QString ShootMode::initialView()
{
    return s_Shot.view;
}

void ShootMode::installFixtures(ComputerManager* manager)
{
    const QVector<NvComputer*> hosts = buildFixtures(s_Shot.fixtures);
    for (NvComputer* host : hosts) {
        manager->addFixtureHost(host);
    }
}

void ShootMode::begin(QQmlApplicationEngine* engine)
{
    QObject* root = engine->rootObjects().value(0);
    s_Window = qobject_cast<QQuickWindow*>(root);
    if (s_Window == nullptr) {
        finish(3, "the root object is not a window");
        return;
    }

    // main.qml goes full screen when it cannot find a desktop environment, and
    // offscreen screens are 800x600, so the shot's size has to be reasserted here.
    s_Window->setVisibility(QWindow::Windowed);
    s_Window->resize(s_Shot.width, s_Shot.height);
    s_Window->requestActivate();
    trace(QStringLiteral("window ready, waiting for the first frame"));

    QTimer::singleShot(s_Shot.timeoutMs, qApp, []() {
        finish(5, "timed out waiting for the scene to settle");
    });

    // Steps start once there is a frame to act on.
    //
    // The guard flag is load-bearing. Offscreen has no vsync, so frames are
    // produced back-to-back and several afterRendering deliveries are already
    // queued before the first one runs -- a handler that disconnects and frees
    // its own QMetaObject::Connection crashes when the next queued copy reads
    // it. Ask "have I started?" instead of trying to unhook.
    QObject::connect(s_Window, &QQuickWindow::afterRendering, s_Window, [engine, root]() {
        if (s_Started) {
            return;
        }
        s_Started = true;

        trace(QStringLiteral("first frame rendered"));

        QTimer::singleShot(s_Shot.settleMs, qApp, [engine, root]() {
            runStep(engine, root, 0);
        });
    }, Qt::QueuedConnection);
}
