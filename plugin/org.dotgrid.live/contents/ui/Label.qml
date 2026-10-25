import QtQuick

// Monospaced text locked to the 40 px dot grid (reference px).
// Every character gets a cell of `pitch` px; `cx0` is the centre of the first
// cell (or `rightEdge` is the right edge of the last cell). `cy` is the line the
// text is centred on: the middle of the capitals ("cap"), the centre of a
// period ("dot", so "....." lands exactly on grid dots) or the ink box ("ink").
// The opaque backing box hides the dots underneath; its edges sit halfway
// between dots so no dot is ever cut in half.
Item {
    id: label

    property string text
    property color color: "black"
    property color bg: "transparent"
    property real size: 64
    property bool bold: true
    property string family: "JetBrains Mono"
    property real pitch: 40
    property real cx0: 140
    property real rightEdge: -1
    property real cy: 140
    property string anchor: "cap"
    property bool boxInk: true          // false: box is one grid row around cy

    readonly property int cells: text.length
    readonly property real firstX: rightEdge >= 0 ? rightEdge - pitch / 2 - (cells - 1) * pitch : cx0
    readonly property real adv: advM.advanceWidth
    readonly property rect anchorRect: (anchor === "dot" ? dotM : anchor === "ink" ? inkM : capM).tightBoundingRect
    readonly property real baseY: cy - (anchorRect.y + anchorRect.height / 2)

    function down(v) { return Math.floor((v - 20 + 0.5) / 40) * 40 + 20; }
    function up(v) { return Math.ceil((v - 20 - 0.5) / 40) * 40 + 20; }

    TextMetrics { id: advM; font: t.metricsFont; text: "0" }
    TextMetrics { id: capM; font: t.metricsFont; text: "H" }
    TextMetrics { id: dotM; font: t.metricsFont; text: "." }
    TextMetrics { id: inkM; font: t.metricsFont; text: label.text }

    Rectangle {
        visible: label.bg.a > 0 && label.cells > 0
        color: label.bg
        x: label.down(label.firstX - label.pitch / 2)
        width: label.up(label.firstX + (label.cells - 0.5) * label.pitch) - x
        y: label.boxInk ? label.down(label.baseY + inkM.tightBoundingRect.y - 2) : label.cy - 20
        height: (label.boxInk ? label.up(label.baseY + inkM.tightBoundingRect.y + inkM.tightBoundingRect.height + 2)
                              : label.cy + 20) - y
    }

    Text {
        id: t
        readonly property font metricsFont: Qt.font({ family: label.family, pixelSize: label.size,
                                                      weight: label.bold ? Font.Bold : Font.Normal,
                                                      features: { "liga": 0, "calt": 0, "dlig": 0 } })
        x: label.firstX - label.adv / 2
        y: label.baseY - baselineOffset
        text: label.text
        color: label.color
        font.family: label.family
        font.pixelSize: label.size
        font.weight: label.bold ? Font.Bold : Font.Normal
        font.letterSpacing: label.pitch - label.adv
        // JetBrains Mono ligates "..", "...", "||" etc. into one glyph; letter
        // spacing is then added once per ligature and the cells drift off the grid
        font.features: ({ "liga": 0, "calt": 0, "dlig": 0 })
    }
}
