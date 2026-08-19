#include "steamgriddb.h"
#include "settings/streamingpreferences.h"

#include <QCoreApplication>
#include <QEventLoop>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>
#include <QUrl>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkRequest>

#define SGDB_BASE "https://www.steamgriddb.com/api/v2"
#define SGDB_TIMEOUT_MS 8000

bool SteamGridDb::isConfigured()
{
    return !StreamingPreferences::get()->steamGridDbApiKey.trimmed().isEmpty();
}

QByteArray SteamGridDb::get(QNetworkAccessManager& nam,
                            const QString& url,
                            const QString& apiKey)
{
    QNetworkRequest request(QUrl{url});
    request.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);

    QNetworkReply* reply = nam.get(request);

    // Same synchronous idiom NvHTTP uses: a local event loop with a hard
    // timeout, since this runs on a pool thread with no event loop of its own.
    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QObject::connect(QCoreApplication::instance(), &QCoreApplication::aboutToQuit,
                     &loop, &QEventLoop::quit);
    QTimer::singleShot(SGDB_TIMEOUT_MS, &loop, &QEventLoop::quit);
    loop.exec(QEventLoop::ExcludeUserInputEvents);

    if (!reply->isFinished()) {
        qWarning() << "SteamGridDB request timed out:" << url;
        reply->abort();
        reply->deleteLater();
        return QByteArray();
    }

    QByteArray body;
    if (reply->error() == QNetworkReply::NoError) {
        body = reply->readAll();
    }
    else {
        qWarning() << "SteamGridDB request failed:" << url << reply->errorString();
    }

    reply->deleteLater();
    return body;
}

int SteamGridDb::searchGameId(QNetworkAccessManager& nam,
                              const QString& apiKey,
                              const QString& gameName)
{
    QString url = QStringLiteral(SGDB_BASE "/search/autocomplete/%1")
            .arg(QString::fromUtf8(QUrl::toPercentEncoding(gameName)));

    QJsonDocument doc = QJsonDocument::fromJson(get(nam, url, apiKey));
    if (!doc.isObject() || !doc.object()["success"].toBool()) {
        return -1;
    }

    QJsonArray results = doc.object()["data"].toArray();
    if (results.isEmpty()) {
        return -1;
    }

    // The autocomplete endpoint is already relevance-ordered, so the first hit
    // is the best guess. Anything cleverer needs fuzzy matching we cannot
    // validate without a human looking at the result.
    return results.first().toObject()["id"].toInt(-1);
}

QImage SteamGridDb::fetchCapsule(const QString& gameName)
{
    QString apiKey = StreamingPreferences::get()->steamGridDbApiKey.trimmed();
    if (apiKey.isEmpty() || gameName.isEmpty()) {
        return QImage();
    }

    QNetworkAccessManager nam;

    int gameId = searchGameId(nam, apiKey, gameName);
    if (gameId < 0) {
        return QImage();
    }

    // 600x900 is the Steam capsule aspect the library grid is laid out for.
    // Static only: the grid cannot play animated art, and asking for it would
    // just waste a round trip.
    QString gridsUrl = QStringLiteral(
                SGDB_BASE "/grids/game/%1?dimensions=600x900&types=static&nsfw=false&limit=1")
            .arg(gameId);

    QJsonDocument doc = QJsonDocument::fromJson(get(nam, gridsUrl, apiKey));
    if (!doc.isObject() || !doc.object()["success"].toBool()) {
        return QImage();
    }

    QJsonArray grids = doc.object()["data"].toArray();
    if (grids.isEmpty()) {
        return QImage();
    }

    QString imageUrl = grids.first().toObject()["url"].toString();
    if (imageUrl.isEmpty()) {
        return QImage();
    }

    QByteArray imageData = get(nam, imageUrl, apiKey);
    if (imageData.isEmpty()) {
        return QImage();
    }

    QImage image;
    if (!image.loadFromData(imageData)) {
        qWarning() << "SteamGridDB returned data that is not a readable image for" << gameName;
        return QImage();
    }

    return image;
}
