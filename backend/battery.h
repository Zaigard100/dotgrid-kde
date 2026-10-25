#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QTimer>

// Battery charge from /sys/class/power_supply (no DBus, no extra deps).
// percent is -1 when the machine has no battery.
class Battery : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int percent READ percent NOTIFY changed)
    Q_PROPERTY(bool charging READ charging NOTIFY changed)
    Q_PROPERTY(bool onBattery READ onBattery NOTIFY changed)
    // polling stops while inactive (element switched off)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(int interval READ interval WRITE setInterval NOTIFY intervalChanged)

public:
    explicit Battery(QObject *parent = nullptr);

    int percent() const { return m_percent; }
    bool charging() const { return m_charging; }
    bool onBattery() const { return m_onBattery; }
    bool active() const { return m_timer.isActive(); }
    void setActive(bool a);
    int interval() const { return m_timer.interval(); }
    void setInterval(int ms);

    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void changed();
    void activeChanged();
    void intervalChanged();

private:
    QTimer m_timer;
    int m_percent = -1;
    bool m_charging = false;
    bool m_onBattery = false;
};
