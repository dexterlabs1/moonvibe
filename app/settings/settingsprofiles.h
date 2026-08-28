#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>

class StreamingPreferences;

// Named stream-quality profiles: save the current quality settings under a name,
// apply a saved one back, and reset the quality settings to the app defaults.
//
// A profile captures only the stream-quality subset of StreamingPreferences
// (resolution, fps, bitrate, vsync/pacing, HDR/YUV444, audio and codec config,
// packet size) -- not input, host or UI preferences. Everything lands in the
// same QSettings the preferences use (so it ends up in Moonvibe.conf), keyed as
// profiles/<name>/<field>. The name last applied or saved is the active profile,
// persisted under a top-level key.
//
// Registered as a QML singleton (see main.cpp), like StreamingPreferences.
class SettingsProfiles : public QObject
{
    Q_OBJECT

    // Saved profile names, sorted.
    Q_PROPERTY(QStringList names READ names NOTIFY namesChanged)

    // The name last applied or saved, or "" when none is active (a fresh reset,
    // a removed active profile, or hand-edited settings that match no profile).
    Q_PROPERTY(QString activeProfile READ activeProfile NOTIFY activeProfileChanged)

    // True when the live quality settings differ from the active profile's stored
    // values, so the UI can show "Balanced - modified". Always false with no
    // active profile. Recomputed on the relevant StreamingPreferences NOTIFYs.
    Q_PROPERTY(bool modified READ modified NOTIFY modifiedChanged)

public:
    explicit SettingsProfiles(StreamingPreferences* prefs, QObject* parent = nullptr);

    QStringList names() const;
    QString activeProfile() const;
    bool modified() const;

    // Snapshot the current quality fields into a profile named `name` and make
    // it active. Trims `name`; a no-op on an empty name. Overwrites an existing
    // profile of the same name.
    Q_INVOKABLE void saveAs(const QString& name);

    // Overwrite the active profile with the current quality fields. No-op when
    // nothing is active.
    Q_INVOKABLE void saveActive();

    // Load a profile's quality fields into StreamingPreferences (which repaints
    // the bound UI and persists), and make it active. No-op on an unknown name.
    Q_INVOKABLE void apply(const QString& name);

    // Delete a profile. If it was active, the active profile clears.
    Q_INVOKABLE void remove(const QString& name);

    // Set the quality fields back to the app defaults and clear the active
    // profile. Saved profiles are kept.
    Q_INVOKABLE void resetToDefaults();

signals:
    void namesChanged();
    void activeProfileChanged();
    void modifiedChanged();

private slots:
    void recomputeModified();

private:
    void setActiveProfile(const QString& name);
    QVariantMap captureCurrent() const;
    QVariantMap readProfile(const QString& name) const;
    void writeProfile(const QString& name, const QVariantMap& fields) const;
    bool profileExists(const QString& name) const;
    bool currentMatches(const QString& name) const;

    StreamingPreferences* m_Prefs;
    QString m_ActiveProfile;
    bool m_Modified;
};
