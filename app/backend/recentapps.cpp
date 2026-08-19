#include "recentapps.h"

#include <QDateTime>
#include <QSettings>

#define SER_RECENTAPPS "recentapps"

RecentApps& RecentApps::get()
{
    static RecentApps s_RecentApps;
    return s_RecentApps;
}

QString RecentApps::keyFor(const QString& computerUuid, int appId)
{
    // QSettings treats '/' as a group separator, which is exactly what we want
    // here: one group per host, one key per app.
    return QString(SER_RECENTAPPS "/%1/%2").arg(computerUuid).arg(appId);
}

void RecentApps::recordLaunch(const QString& computerUuid, int appId)
{
    if (computerUuid.isEmpty() || appId == 0) {
        return;
    }

    QSettings settings;
    settings.setValue(keyFor(computerUuid, appId),
                      QDateTime::currentMSecsSinceEpoch());
}

qint64 RecentApps::lastPlayed(const QString& computerUuid, int appId) const
{
    if (computerUuid.isEmpty() || appId == 0) {
        return 0;
    }

    QSettings settings;
    return settings.value(keyFor(computerUuid, appId), 0).toLongLong();
}

void RecentApps::forgetComputer(const QString& computerUuid)
{
    if (computerUuid.isEmpty()) {
        return;
    }

    QSettings settings;
    settings.beginGroup(SER_RECENTAPPS);
    settings.remove(computerUuid);
    settings.endGroup();
}
