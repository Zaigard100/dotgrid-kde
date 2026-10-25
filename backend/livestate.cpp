#include "livestate.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

namespace {
const QString kService = QStringLiteral("org.dotgrid.Live");
const QString kPath = QStringLiteral("/org/dotgrid/Live");
const QString kIface = QStringLiteral("org.dotgrid.Live");
}

LiveState::LiveState(QObject *parent)
    : QObject(parent)
{
    m_file = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
        + QStringLiteral("/dotgrid/live.json");

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(kService, kPath, kIface, QStringLiteral("Changed"), this, SLOT(onChanged(QString)));
    bus.connect(kService, kPath, kIface, QStringLiteral("Levels"), this, SLOT(onLevels(QByteArray)));

    m_serviceWatch = new QDBusServiceWatcher(kService, bus,
        QDBusServiceWatcher::WatchForRegistration | QDBusServiceWatcher::WatchForUnregistration, this);
    connect(m_serviceWatch, &QDBusServiceWatcher::serviceRegistered, this, &LiveState::fetch);
    connect(m_serviceWatch, &QDBusServiceWatcher::serviceUnregistered, this, [this] {
        onLevels({});         // no service, no data: the wallpaper animates on its own
        readFile();
    });

    connect(&m_watch, &QFileSystemWatcher::fileChanged, this, [this] {
        watchFile();          // editors replace the file; re-add it
        if (!m_daemon)
            readFile();
    });
    connect(&m_watch, &QFileSystemWatcher::directoryChanged, this, [this] {
        watchFile();
        if (!m_daemon)
            readFile();
    });
    watchFile();

    if (bus.interface() && bus.interface()->isServiceRegistered(kService))
        fetch();
    else
        readFile();
}

void LiveState::watchFile()
{
    const QString dir = QFileInfo(m_file).absolutePath();
    if (QFileInfo::exists(dir) && !m_watch.directories().contains(dir))
        m_watch.addPath(dir);
    if (QFileInfo::exists(m_file) && !m_watch.files().contains(m_file))
        m_watch.addPath(m_file);
}

void LiveState::fetch()
{
    QDBusMessage call = QDBusMessage::createMethodCall(kService, kPath, kIface, QStringLiteral("Status"));
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(call), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<QString> reply = *w;
        w->deleteLater();
        if (reply.isValid())
            onChanged(reply.value());
        else
            readFile();
    });
}

void LiveState::onChanged(const QString &json)
{
    const QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    if (doc.isObject())
        apply(doc.object().toVariantMap(), true);
}

void LiveState::onLevels(const QByteArray &data)
{
    const int source = data.isEmpty() ? 0 : quint8(data.at(0));
    QVariantList levels;
    levels.reserve(data.size() > 0 ? data.size() - 1 : 0);
    for (int i = 1; i < data.size(); ++i)
        levels.append(quint8(data.at(i)) / 255.0);
    if (source == m_levelsSource && levels == m_levels)
        return;
    m_levelsSource = source;
    m_levels = levels;
    Q_EMIT levelsChanged();
}

void LiveState::readFile()
{
    QFile f(m_file);
    QVariantMap map;
    if (f.open(QIODevice::ReadOnly)) {
        const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        if (doc.isObject())
            map = doc.object().toVariantMap();
    }
    map.insert(QStringLiteral("daemon"), false);
    apply(map, false);
}

void LiveState::apply(const QVariantMap &status, bool daemon)
{
    if (status == m_status && daemon == m_daemon)
        return;
    m_status = status;
    m_daemon = daemon;
    Q_EMIT statusChanged();
}

void LiveState::toggle()
{
    QDBusConnection::sessionBus().asyncCall(
        QDBusMessage::createMethodCall(kService, kPath, kIface, QStringLiteral("Toggle")));
}
