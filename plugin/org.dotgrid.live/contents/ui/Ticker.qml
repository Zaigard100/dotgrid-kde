import QtQuick

// Animation clock of one element: `t` advances only while running, so a
// paused or switched-off element keeps its pose and resumes from it.
// It wakes `rate` times per second and not at all while stopped.
Timer {
    id: ticker

    property real t: 0
    property real rate: 30

    property double last: 0

    interval: Math.max(16, Math.round(1000 / rate))
    repeat: true
    onRunningChanged: last = Date.now()
    onTriggered: {
        const now = Date.now();
        // a long gap (suspend, stalled shell) must not make things jump
        t += Math.min(0.25, (now - last) / 1000);
        last = now;
    }
}
