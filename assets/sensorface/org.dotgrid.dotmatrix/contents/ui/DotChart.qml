import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

// Sensors as a dot matrix in the text colour of the theme, so it follows day
// and night by itself. Two layouts: a column per sensor (CPU cores), or the
// history of the sensors scrolling right to left (network, memory). Unlit
// cells stay as dim dots: the grid of the wallpaper. Painted only when a
// sensor reports a new value; requestPaint() calls within a frame coalesce.
Canvas {
    id: chart

    property var sensorIds: []
    property int mode: 0                   // 0 auto, 1 columns, 2 history
    property int updateRateLimit: 0
    property real pitch: Math.max(3, Math.round(height / 9))

    readonly property bool columns: mode === 1 || (mode === 0 && sensorIds.length >= 3)
    readonly property int rows: Math.max(3, Math.floor(height / pitch))
    readonly property int historyLength: Math.max(1, Math.floor(width / pitch))
    readonly property color ink: Kirigami.Theme.textColor

    property var sensors: []
    property var history: []               // oldest first; each entry: raw values

    implicitWidth: columns ? sensorIds.length * pitch : 24 * pitch

    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onColumnsChanged: { history = []; requestPaint() }

    Instantiator {
        model: chart.sensorIds
        delegate: Sensors.Sensor {
            sensorId: modelData
            updateRateLimit: chart.updateRateLimit
            onValueChanged: chart.changed(index)
        }
        onObjectAdded: (index, object) => { chart.sensors[index] = object }
        onObjectRemoved: (index, object) => { chart.sensors.splice(index, 1); chart.history = [] }
    }

    function changed(index) {
        // history: one sample per update of the first sensor
        if (!columns && index === 0) {
            const sample = sensors.map(s => s ? s.value || 0 : 0)
            history.push(sample)
            while (history.length > historyLength)
                history.shift()
        }
        requestPaint()
    }

    function fraction(sensor, value, autoMax) {
        const max = sensor && sensor.maximum > 0 ? sensor.maximum : autoMax
        return max > 0 ? Math.max(0, Math.min(1, value / max)) : 0
    }

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const p = pitch
        const dot = Math.max(1, Math.round(p * 0.6))
        const off = (p - dot) / 2
        const n = columns ? sensorIds.length : historyLength
        const x0 = Math.floor((width - n * p) / 2)
        const y0 = Math.floor((height - rows * p) / 2)

        // lit[c] = rows lit in column c (strong), soft[c] = by the second sensor
        const lit = [], soft = []
        if (columns) {
            for (let c = 0; c < n; c++)
                lit.push(Math.round(fraction(sensors[c], sensors[c] ? sensors[c].value || 0 : 0, 100) * rows))
        } else {
            // sensors without a maximum (network) scale to the peak on screen,
            // with a floor so an idle link does not fill the box with noise
            let peak = 16384
            for (const s of history)
                for (const v of s)
                    peak = Math.max(peak, v)
            const pad = n - history.length
            for (let c = 0; c < n; c++) {
                const s = history[c - pad]
                lit.push(s ? Math.round(fraction(sensors[0], s[0], peak) * rows) : 0)
                soft.push(s && s.length > 1 ? Math.round(fraction(sensors[1], s[1], peak) * rows) : 0)
            }
        }

        for (let c = 0; c < n; c++) {
            for (let r = 0; r < rows; r++) {
                const h = rows - r            // 1 = bottom row
                ctx.globalAlpha = h <= lit[c] ? 1 : (soft.length && h <= soft[c] ? 0.5 : 0.16)
                ctx.fillStyle = ink
                ctx.fillRect(x0 + c * p + off, y0 + r * p + off, dot, dot)
            }
        }
    }
}
