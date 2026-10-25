import QtQuick
import "../backend"

// Animated galaxy from the C++ backend; same placement API as Galaxy.qml,
// which NightScene falls back to when the backend cannot be loaded.
StarField {
    id: field

    property real s: 1
    property real ox: 0
    property real oy: 0
    property real cx: 1820
    property real cy: 800
    property int stars: 2600
    count: stars
    readonly property rect area: Qt.rect(1180, 100, 1380, 1400)

    x: ox + area.x * s
    y: oy + area.y * s
    width: Math.ceil(area.width * s)
    height: Math.ceil(area.height * s)
    scaleFactor: s
    center: Qt.point(cx - area.x, cy - area.y)
}
