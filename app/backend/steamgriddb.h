#pragma once

#include <QImage>
#include <QString>

// Fetches 600x900 capsule artwork from SteamGridDB.
//
// Hosts serve whatever art the game launcher happened to have, and for
// non-Steam entries that is usually a generic placeholder. SteamGridDB has
// proper capsules for almost everything, which is what makes a Deck library
// grid look like a library rather than a list of grey boxes.
//
// Every call is synchronous and is expected to run on BoxArtManager's thread
// pool, never on the UI thread.
class SteamGridDb
{
public:
    // False when no API key is configured, in which case callers should not
    // bother attempting a fetch. SteamGridDB requires a key for all endpoints.
    static bool isConfigured();

    // Best 600x900 capsule for this game name, or a null QImage if there is no
    // key, no match, or anything at all goes wrong. Never throws.
    static QImage fetchCapsule(const QString& gameName);

private:
    // Returns the SteamGridDB game id for a name, or -1.
    static int searchGameId(class QNetworkAccessManager& nam,
                            const QString& apiKey,
                            const QString& gameName);

    static QByteArray get(class QNetworkAccessManager& nam,
                          const QString& url,
                          const QString& apiKey);
};
