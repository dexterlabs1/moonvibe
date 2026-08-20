#pragma once

#include "backend/boxartmanager.h"
#include "backend/computermanager.h"
#include "backend/recentapps.h"
#include "streaming/session.h"

#include <QObject>

// Backs the home screen, which is deliberately NOT a host list.
//
// Everything here is cross-host on purpose: the home screen's whole premise is
// that a PC is a property of a game, not a place you navigate to first. So it
// answers "what would you most likely play right now, and what stands in the
// way" across every known host at once.
class HomeModel : public QObject
{
    Q_OBJECT

public:
    explicit HomeModel(QObject* parent = nullptr);

    // Must be called before anything else.
    Q_INVOKABLE void initialize(ComputerManager* computerManager);

    // Recently played apps across every host, newest first, with the host's
    // current state folded into each entry so QML never has to correlate two
    // models. A running session always leads.
    Q_INVOKABLE QVariantList recents(int maxCount);

    // Whether any host is known at all. False means first run, and the home
    // screen shows setup instead of a game.
    Q_INVOKABLE bool hasHosts();

    Q_INVOKABLE Session* createSessionFor(int computerIndex, int appId);

signals:
    // Any change that could alter what the home screen should show: a host
    // coming online, pairing completing, an app list arriving, box art loading.
    void homeChanged();

private slots:
    void handleComputerStateChanged(NvComputer* computer);
    void handleBoxArtLoaded(NvComputer* computer, NvApp app, QUrl image);

private:
    // Same vocabulary the host cards use, resolved once here.
    static QString stateFor(NvComputer* computer);

    ComputerManager* m_ComputerManager;
    BoxArtManager m_BoxArtManager;
};
