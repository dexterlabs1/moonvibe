#include "boxartmanager.h"
#include "../path.h"
#include "steamgriddb.h"

#include <QImageReader>
#include <QImageWriter>

BoxArtManager::BoxArtManager(QObject *parent) :
    QObject(parent),
    m_BoxArtDir(Path::getBoxArtCacheDir()),
    m_ThreadPool(this)
{
    // 4 is a good balance between fast loading for large
    // app grids and not crushing GFE with tons of requests
    // and causing UI jank from constantly stalling to decode
    // new images.
    m_ThreadPool.setMaxThreadCount(4);
    if (!m_BoxArtDir.exists()) {
        m_BoxArtDir.mkpath(".");
    }
}

QString
BoxArtManager::getFilePathForBoxArt(NvComputer* computer, int appId)
{
    QDir dir = m_BoxArtDir;

    // Create the cache directory if it did not already exist
    if (!dir.exists(computer->uuid)) {
        dir.mkdir(computer->uuid);
    }

    // Change to this computer's box art cache folder
    dir.cd(computer->uuid);

    // Try to open the cached file
    return dir.filePath(QString::number(appId) + ".png");
}

class NetworkBoxArtLoadTask : public QObject, public QRunnable
{
    Q_OBJECT

public:
    NetworkBoxArtLoadTask(BoxArtManager* boxArtManager, NvComputer* computer, NvApp& app)
        : m_Bam(boxArtManager),
          m_Computer(computer),
          m_App(app)
    {
        connect(this, &NetworkBoxArtLoadTask::boxArtFetchCompleted,
                boxArtManager, &BoxArtManager::handleBoxArtLoadComplete);
    }

signals:
    void boxArtFetchCompleted(NvComputer* computer, NvApp app, QUrl image);

private:
    void run()
    {
        QUrl image = m_Bam->loadBoxArtFromNetwork(m_Computer, m_App);
        if (image.isEmpty()) {
            // Give it another shot if it fails once
            image = m_Bam->loadBoxArtFromNetwork(m_Computer, m_App);
        }
        emit boxArtFetchCompleted(m_Computer, m_App, image);
    }

    BoxArtManager* m_Bam;
    NvComputer* m_Computer;
    NvApp m_App;
};

QUrl BoxArtManager::loadBoxArt(NvComputer* computer, NvApp& app)
{
    // Try to open the cached file if it exists and contains data
    QFile cacheFile(getFilePathForBoxArt(computer, app.id));
    if (cacheFile.exists() && cacheFile.size() > 0) {
        return QUrl::fromLocalFile(cacheFile.fileName());
    }

    // If we get here, we need to fetch asynchronously.
    // Kick off a worker on our thread pool to do just that.
    NetworkBoxArtLoadTask* netLoadTask = new NetworkBoxArtLoadTask(this, computer, app);
    m_ThreadPool.start(netLoadTask);

    // Return the placeholder then we can notify the caller
    // later when the real image is ready.
    return QUrl("qrc:/res/no_app_image.png");
}

void BoxArtManager::deleteBoxArt(NvComputer* computer)
{
    QDir dir(Path::getBoxArtCacheDir());

    // Delete everything in this computer's box art directory
    if (dir.cd(computer->uuid)) {
        dir.removeRecursively();
    }
}

void BoxArtManager::handleBoxArtLoadComplete(NvComputer* computer, NvApp app, QUrl image)
{
    if (!image.isEmpty()) {
        emit boxArtLoadComplete(computer, app, image);
    }
}

QUrl BoxArtManager::loadBoxArtFromNetwork(NvComputer* computer, NvApp& app)
{
    QString cachePath = getFilePathForBoxArt(computer, app.id);
    QImage image;

    // Prefer SteamGridDB when the user has supplied a key. Hosts serve whatever
    // art the launcher had, which for non-Steam entries is usually a generic
    // placeholder; SteamGridDB has a real 600x900 capsule for most things.
    // Falling back to the host keeps the client fully functional without a key
    // and whenever a title simply is not in their database.
    if (SteamGridDb::isConfigured()) {
        image = SteamGridDb::fetchCapsule(app.name);
    }

    if (image.isNull()) {
        NvHTTP http(computer);
        try {
            image = http.getBoxArt(app.id);
        } catch (...) {}
    }

    // Cache the box art on disk if it loaded
    if (!image.isNull()) {
        if (image.save(cachePath)) {
            return QUrl::fromLocalFile(cachePath);
        }
        else {
            // A failed save() may leave a zero byte file. Make sure that's removed.
            QFile(cachePath).remove();
        }
    }

    return QUrl();
}

#include "boxartmanager.moc"
