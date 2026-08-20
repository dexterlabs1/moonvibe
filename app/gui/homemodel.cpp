#include "homemodel.h"

#include <QUrl>
#include <algorithm>

HomeModel::HomeModel(QObject* parent)
    : QObject(parent),
      m_ComputerManager(nullptr)
{
    connect(&m_BoxArtManager, &BoxArtManager::boxArtLoadComplete,
            this, &HomeModel::handleBoxArtLoaded);
}

void HomeModel::initialize(ComputerManager* computerManager)
{
    m_ComputerManager = computerManager;
    connect(m_ComputerManager, &ComputerManager::computerStateChanged,
            this, &HomeModel::handleComputerStateChanged);
}

void HomeModel::handleComputerStateChanged(NvComputer*)
{
    // Anything about any host can change what the home screen should offer, and
    // rebuilding it is cheap, so there is no point being clever about which.
    emit homeChanged();
}

void HomeModel::handleBoxArtLoaded(NvComputer*, NvApp, QUrl)
{
    emit homeChanged();
}

bool HomeModel::hasHosts()
{
    return m_ComputerManager != nullptr && !m_ComputerManager->getComputers().isEmpty();
}

QString HomeModel::stateFor(NvComputer* computer)
{
    if (computer->state == NvComputer::CS_UNKNOWN) {
        return QStringLiteral("checking");
    }
    else if (computer->state == NvComputer::CS_OFFLINE) {
        // Same test ComputerModel uses for its wakeable role: we can only
        // offer to wake a host whose MAC we actually learned.
        return !computer->macAddress.isEmpty() ? QStringLiteral("asleep")
                                              : QStringLiteral("offline");
    }
    else if (computer->pairState != NvComputer::PS_PAIRED) {
        return QStringLiteral("unpaired");
    }
    else {
        return QStringLiteral("ready");
    }
}

QVariantList HomeModel::recents(int maxCount)
{
    QVariantList result;
    if (m_ComputerManager == nullptr) {
        return result;
    }

    struct Entry {
        qint64 lastPlayed;
        bool running;
        int computerIndex;
        NvComputer* computer;
        NvApp app;
    };

    QVector<Entry> entries;
    const QVector<NvComputer*> computers = m_ComputerManager->getComputers();

    for (int i = 0; i < computers.count(); i++) {
        NvComputer* computer = computers.at(i);
        QReadLocker lock(&computer->lock);

        for (const NvApp& app : computer->appList) {
            if (app.hidden) {
                continue;
            }

            qint64 lastPlayed = RecentApps::get().lastPlayed(computer->uuid, app.id);
            bool running = computer->currentGameId == app.id;

            // Never played and not running: it belongs in the full library, not
            // on the home screen.
            if (lastPlayed == 0 && !running) {
                continue;
            }

            entries.append({lastPlayed, running, i, computer, app});
        }
    }

    std::sort(entries.begin(), entries.end(), [](const Entry& a, const Entry& b) {
        // A live session is always the thing you most likely want back.
        if (a.running != b.running) {
            return a.running;
        }
        return a.lastPlayed > b.lastPlayed;
    });

    for (int i = 0; i < entries.count() && result.count() < maxCount; i++) {
        Entry& e = entries[i];
        QReadLocker lock(&e.computer->lock);

        QVariantMap entry;
        entry["computerIndex"] = e.computerIndex;
        entry["hostName"] = e.computer->name;
        entry["hostState"] = stateFor(e.computer);
        entry["appId"] = e.app.id;
        entry["appName"] = e.app.name;
        entry["boxart"] = m_BoxArtManager.loadBoxArt(e.computer, e.app);
        entry["lastPlayed"] = e.lastPlayed;
        entry["running"] = e.running;
        result.append(entry);
    }

    return result;
}

Session* HomeModel::createSessionFor(int computerIndex, int appId)
{
    if (m_ComputerManager == nullptr) {
        return nullptr;
    }

    const QVector<NvComputer*> computers = m_ComputerManager->getComputers();
    if (computerIndex < 0 || computerIndex >= computers.count()) {
        return nullptr;
    }

    NvComputer* computer = computers.at(computerIndex);

    NvApp match;
    {
        QReadLocker lock(&computer->lock);
        for (const NvApp& app : computer->appList) {
            if (app.id == appId) {
                match = app;
                break;
            }
        }
    }

    if (!match.isInitialized()) {
        return nullptr;
    }

    // Stamp it the same way the library does, so launching from home and
    // launching from the grid keep the same history.
    RecentApps::get().recordLaunch(computer->uuid, match.id);

    return new Session(computer, match);
}
