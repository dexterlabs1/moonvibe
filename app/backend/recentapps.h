#pragma once

#include <QString>

// Tracks when each app was last launched, per host.
//
// This deliberately does NOT live on NvApp. NvApp::operator== drives the
// `appList == newAppList` early-out in NvComputer::updateAppList(), and the
// app list arriving from the host never carries a client-side timestamp — so a
// last-played field there would compare unequal on every poll, re-assign the
// list, and signal a state change forever. Keeping it in a side table keeps
// host data and client annotations separate.
class RecentApps
{
public:
    static RecentApps& get();

    // Stamp an app as launched right now.
    void recordLaunch(const QString& computerUuid, int appId);

    // Milliseconds since epoch, or 0 if this app has never been launched.
    qint64 lastPlayed(const QString& computerUuid, int appId) const;

    // Forget one host's history (used when a host is deleted).
    void forgetComputer(const QString& computerUuid);

private:
    RecentApps() {}

    static QString keyFor(const QString& computerUuid, int appId);
};
