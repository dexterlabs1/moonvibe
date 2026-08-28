#include "settingsprofiles.h"
#include "streamingpreferences.h"

#include <QSettings>

// The QSettings layout. Profiles live under a "profiles" group, one subgroup per
// profile; the active profile name is a sibling top-level key so it never shows
// up in childGroups() alongside the profiles themselves.
#define SER_PROFILES_GROUP "profiles"
#define SER_ACTIVEPROFILE "activeprofile"

// The quality fields a profile stores, by their QML property name. Kept in one
// list so capture/read/compare cannot disagree about the set.
namespace
{
const char* const k_QualityKeys[] = {
    "width", "height", "fps", "bitrateKbps", "unlockBitrate", "autoAdjustBitrate",
    "enableVsync", "framePacing", "enableHdr", "enableYUV444", "audioConfig",
    "videoCodecConfig", "packetSize",
};
}

SettingsProfiles::SettingsProfiles(StreamingPreferences* prefs, QObject* parent)
    : QObject(parent),
      m_Prefs(prefs),
      m_Modified(false)
{
    QSettings settings;
    m_ActiveProfile = settings.value(QStringLiteral(SER_ACTIVEPROFILE), QString()).toString();

    // If the persisted active profile no longer exists (deleted out from under
    // us, or never saved), treat it as none active.
    if (!m_ActiveProfile.isEmpty() && !profileExists(m_ActiveProfile)) {
        m_ActiveProfile.clear();
    }

    // Recompute the "modified" flag whenever a quality field changes. These are
    // exactly the NOTIFY signals StreamingPreferences emits for the captured
    // fields (displayModeChanged covers width/height/fps). packetSize has no
    // signal and is never touched by the settings UI, so it needs no connection.
    connect(m_Prefs, &StreamingPreferences::displayModeChanged, this, &SettingsProfiles::recomputeModified);
    connect(m_Prefs, &StreamingPreferences::bitrateChanged, this, &SettingsProfiles::recomputeModified);
    connect(m_Prefs, &StreamingPreferences::unlockBitrateChanged, this, &SettingsProfiles::recomputeModified);
    connect(m_Prefs, &StreamingPreferences::autoAdjustBitrateChanged, this, &SettingsProfiles::recomputeModified);
    connect(m_Prefs, &StreamingPreferences::enableVsyncChanged, this, &SettingsProfiles::recomputeModified);
    connect(m_Prefs, &StreamingPreferences::framePacingChanged, this, &SettingsProfiles::recomputeModified);
    connect(m_Prefs, &StreamingPreferences::enableHdrChanged, this, &SettingsProfiles::recomputeModified);
    connect(m_Prefs, &StreamingPreferences::enableYUV444Changed, this, &SettingsProfiles::recomputeModified);
    connect(m_Prefs, &StreamingPreferences::audioConfigChanged, this, &SettingsProfiles::recomputeModified);
    connect(m_Prefs, &StreamingPreferences::videoCodecConfigChanged, this, &SettingsProfiles::recomputeModified);

    recomputeModified();
}

QStringList SettingsProfiles::names() const
{
    QSettings settings;
    settings.beginGroup(QStringLiteral(SER_PROFILES_GROUP));
    QStringList result = settings.childGroups();
    settings.endGroup();
    result.sort(Qt::CaseInsensitive);
    return result;
}

QString SettingsProfiles::activeProfile() const
{
    return m_ActiveProfile;
}

bool SettingsProfiles::modified() const
{
    return m_Modified;
}

bool SettingsProfiles::profileExists(const QString& name) const
{
    if (name.isEmpty()) {
        return false;
    }
    QSettings settings;
    settings.beginGroup(QStringLiteral(SER_PROFILES_GROUP));
    settings.beginGroup(name);
    const bool exists = !settings.childKeys().isEmpty();
    settings.endGroup();
    settings.endGroup();
    return exists;
}

QVariantMap SettingsProfiles::captureCurrent() const
{
    QVariantMap m;
    m[QStringLiteral("width")] = m_Prefs->width;
    m[QStringLiteral("height")] = m_Prefs->height;
    m[QStringLiteral("fps")] = m_Prefs->fps;
    m[QStringLiteral("bitrateKbps")] = m_Prefs->bitrateKbps;
    m[QStringLiteral("unlockBitrate")] = m_Prefs->unlockBitrate;
    m[QStringLiteral("autoAdjustBitrate")] = m_Prefs->autoAdjustBitrate;
    m[QStringLiteral("enableVsync")] = m_Prefs->enableVsync;
    m[QStringLiteral("framePacing")] = m_Prefs->framePacing;
    m[QStringLiteral("enableHdr")] = m_Prefs->enableHdr;
    m[QStringLiteral("enableYUV444")] = m_Prefs->enableYUV444;
    m[QStringLiteral("audioConfig")] = static_cast<int>(m_Prefs->audioConfig);
    m[QStringLiteral("videoCodecConfig")] = static_cast<int>(m_Prefs->videoCodecConfig);
    m[QStringLiteral("packetSize")] = m_Prefs->packetSize;
    return m;
}

QVariantMap SettingsProfiles::readProfile(const QString& name) const
{
    QVariantMap m;
    QSettings settings;
    settings.beginGroup(QStringLiteral(SER_PROFILES_GROUP));
    settings.beginGroup(name);
    for (const char* const key : k_QualityKeys) {
        const QString k = QString::fromLatin1(key);
        if (settings.contains(k)) {
            m[k] = settings.value(k);
        }
    }
    settings.endGroup();
    settings.endGroup();
    return m;
}

void SettingsProfiles::writeProfile(const QString& name, const QVariantMap& fields) const
{
    QSettings settings;
    settings.beginGroup(QStringLiteral(SER_PROFILES_GROUP));
    settings.beginGroup(name);
    for (auto it = fields.constBegin(); it != fields.constEnd(); ++it) {
        settings.setValue(it.key(), it.value());
    }
    settings.endGroup();
    settings.endGroup();
}

// Compares typed values rather than raw QVariants: QSettings' native (INI) format
// can round-trip a bool as the string "true", so a QVariant == QVariant check
// against a real bool would spuriously report a mismatch.
bool SettingsProfiles::currentMatches(const QString& name) const
{
    if (!profileExists(name)) {
        return false;
    }

    QSettings settings;
    settings.beginGroup(QStringLiteral(SER_PROFILES_GROUP));
    settings.beginGroup(name);

    const bool matches =
        settings.value(QStringLiteral("width")).toInt() == m_Prefs->width &&
        settings.value(QStringLiteral("height")).toInt() == m_Prefs->height &&
        settings.value(QStringLiteral("fps")).toInt() == m_Prefs->fps &&
        settings.value(QStringLiteral("bitrateKbps")).toInt() == m_Prefs->bitrateKbps &&
        settings.value(QStringLiteral("unlockBitrate")).toBool() == m_Prefs->unlockBitrate &&
        settings.value(QStringLiteral("autoAdjustBitrate")).toBool() == m_Prefs->autoAdjustBitrate &&
        settings.value(QStringLiteral("enableVsync")).toBool() == m_Prefs->enableVsync &&
        settings.value(QStringLiteral("framePacing")).toBool() == m_Prefs->framePacing &&
        settings.value(QStringLiteral("enableHdr")).toBool() == m_Prefs->enableHdr &&
        settings.value(QStringLiteral("enableYUV444")).toBool() == m_Prefs->enableYUV444 &&
        settings.value(QStringLiteral("audioConfig")).toInt() == static_cast<int>(m_Prefs->audioConfig) &&
        settings.value(QStringLiteral("videoCodecConfig")).toInt() == static_cast<int>(m_Prefs->videoCodecConfig) &&
        settings.value(QStringLiteral("packetSize")).toInt() == m_Prefs->packetSize;

    settings.endGroup();
    settings.endGroup();
    return matches;
}

void SettingsProfiles::recomputeModified()
{
    const bool m = !m_ActiveProfile.isEmpty() && !currentMatches(m_ActiveProfile);
    if (m != m_Modified) {
        m_Modified = m;
        emit modifiedChanged();
    }
}

void SettingsProfiles::setActiveProfile(const QString& name)
{
    if (name == m_ActiveProfile) {
        return;
    }
    m_ActiveProfile = name;

    QSettings settings;
    settings.setValue(QStringLiteral(SER_ACTIVEPROFILE), m_ActiveProfile);

    emit activeProfileChanged();
    recomputeModified();
}

void SettingsProfiles::saveAs(const QString& name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        return;
    }

    const bool isNew = !profileExists(trimmed);
    writeProfile(trimmed, captureCurrent());
    if (isNew) {
        emit namesChanged();
    }

    // Snapshot is the live state, so this profile is active and unmodified.
    setActiveProfile(trimmed);
    recomputeModified();
}

void SettingsProfiles::saveActive()
{
    if (m_ActiveProfile.isEmpty()) {
        return;
    }
    writeProfile(m_ActiveProfile, captureCurrent());
    recomputeModified();
}

void SettingsProfiles::apply(const QString& name)
{
    if (!profileExists(name)) {
        return;
    }

    // Route through StreamingPreferences so the members are written AND their
    // NOTIFY signals fire (repainting the bound settings controls) and the
    // change is persisted.
    m_Prefs->applyQualityFields(readProfile(name));

    setActiveProfile(name);
    recomputeModified();
}

void SettingsProfiles::remove(const QString& name)
{
    if (!profileExists(name)) {
        return;
    }

    QSettings settings;
    settings.beginGroup(QStringLiteral(SER_PROFILES_GROUP));
    settings.remove(name);
    settings.endGroup();

    if (name == m_ActiveProfile) {
        setActiveProfile(QString());
    }
    emit namesChanged();
}

void SettingsProfiles::resetToDefaults()
{
    m_Prefs->resetQualityFieldsToDefaults();
    setActiveProfile(QString());
    recomputeModified();
}
