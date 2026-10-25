#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QQmlEngine>
#include <QVariantMap>

class QDBusServiceWatcher;

// State of the wallpaper from dotgrid-livectl (DBus org.dotgrid.Live).
// While the service is not running, the manual settings are read from
// ~/.config/dotgrid/live.json instead (inotify, no polling); there is no
// autopause then. `status` is the same JSON object the service publishes.
class LiveState : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantMap status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool daemon READ daemon NOTIFY statusChanged)
    // external data for the night bars/pipes: 0 none, 1 audio, 2 system
    Q_PROPERTY(int levelsSource READ levelsSource NOTIFY levelsChanged)
    // 26 bar levels then 4 pipe levels, 0..1
    Q_PROPERTY(QVariantList levels READ levels NOTIFY levelsChanged)

public:
    explicit LiveState(QObject *parent = nullptr);

    QVariantMap status() const { return m_status; }
    bool daemon() const { return m_daemon; }
    int levelsSource() const { return m_levelsSource; }
    QVariantList levels() const { return m_levels; }

    // forwards to the service (no-op without it)
    Q_INVOKABLE void toggle();

Q_SIGNALS:
    void statusChanged();
    void levelsChanged();

private Q_SLOTS:
    void onChanged(const QString &json);
    void onLevels(const QByteArray &data);

private:
    void fetch();
    void readFile();
    void apply(const QVariantMap &status, bool daemon);
    void watchFile();

    QVariantMap m_status;
    bool m_daemon = false;
    int m_levelsSource = 0;
    QVariantList m_levels;
    QString m_file;
    QFileSystemWatcher m_watch;
    QDBusServiceWatcher *m_serviceWatch = nullptr;
};
