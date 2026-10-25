#include "battery.h"

#include <QDir>
#include <QFile>

namespace {
QByteArray readSys(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return f.readAll().trimmed();
}
}

Battery::Battery(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(60000);
    connect(&m_timer, &QTimer::timeout, this, &Battery::refresh);
    refresh();
    m_timer.start();
}

void Battery::setActive(bool a)
{
    if (a == m_timer.isActive())
        return;
    if (a) {
        refresh();
        m_timer.start();
    } else {
        m_timer.stop();
    }
    Q_EMIT activeChanged();
}

void Battery::setInterval(int ms)
{
    if (ms == m_timer.interval())
        return;
    m_timer.setInterval(ms);
    Q_EMIT intervalChanged();
}

void Battery::refresh()
{
    const QString root = QStringLiteral("/sys/class/power_supply");
    int energy = 0, full = 0, batteries = 0;
    bool charging = false, discharging = false;
    for (const QString &dev : QDir(root).entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        const QString base = root + QLatin1Char('/') + dev + QLatin1Char('/');
        if (readSys(base + QStringLiteral("type")) != "Battery")
            continue;
        if (readSys(base + QStringLiteral("scope")) == "Device")
            continue; // mice, headsets
        const int cap = readSys(base + QStringLiteral("capacity")).toInt();
        energy += cap;
        full += 100;
        ++batteries;
        const QByteArray status = readSys(base + QStringLiteral("status"));
        charging |= status == "Charging";
        discharging |= status == "Discharging";
    }
    const int percent = batteries ? qRound(100.0 * energy / full) : -1;
    if (percent == m_percent && charging == m_charging && discharging == m_onBattery)
        return;
    m_percent = percent;
    m_charging = charging;
    m_onBattery = discharging;
    Q_EMIT changed();
}
