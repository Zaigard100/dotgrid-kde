import QtQuick

// Night composition. Everything sits on the 40 px grid of the 2560x1600
// reference frame: text in the cells between dots, the J/M/I periods and
// the bar gaps on the dots themselves.
Rectangle {
    id: scene

    property real s: 1
    property real ox: 0                 // item px: centring for other aspects
    property real oy: 0
    property real dy: 0                 // reference px, whole grid steps: vertical centring
    property string clockFont: "JetBrains Mono"
    property string clockText: ""       // "unix | HH:mm:ss", where the counters used to be
    property int fps: 15
    property int galaxyStars: 2600
    property bool galaxyTwinkle: true
    property bool galaxyPulse: true
    property int galaxyHz: 10           // galaxy updates per second (it moves < 1 px per frame)
    property real barsSpeed: 1          // generative waves
    property real pipesSpeed: 1
    property real galaxyTurnMinutes: 4   // one turn of the outer edge; the core turns faster
    // which elements move; a stopped element keeps its current pose
    property bool runGalaxy: true
    property bool runBars: true
    property bool runPipes: true
    property var markers: [9, 11, 1]    // J, M, I positions (0..25) on their dot rows

    // external data from dotgrid-livectl: source 0 none, 1 audio spectrum,
    // 2 system load; levels = 26 bars + 4 pipes, 0..1
    property int levelsSource: 0
    property var levels: []

    // ---- one frame clock for the whole scene ----
    // Every tick renders one frame, so all elements advance on the same tick
    // (separate timers would multiply the frames). Each element has its own
    // time that only advances while it runs, so a stopped one keeps its pose.
    // External levels are sampled here too, never on arrival.
    QtObject { id: galaxyT; property real t: 30 }
    QtObject { id: barsT; property real t: 7 }
    QtObject { id: pipesT; property real t: 3 }
    Ticker {
        id: frame
        rate: scene.fps
        running: scene.runGalaxy || scene.runBars || scene.runPipes
        onTChanged: {
            const dt = t - prev;
            prev = t;
            // StarField turns its outer edge once per 240 s of its own time
            if (scene.runGalaxy) galaxyT.t += dt * 4 / Math.max(0.25, scene.galaxyTurnMinutes);
            if (scene.runBars) barsT.t += dt * scene.barsSpeed;
            if (scene.runPipes) pipesT.t += dt * scene.pipesSpeed;
            if (scene.runBars || scene.runPipes)
                scene.updateLevels(dt);
        }
        property real prev: 0
    }

    // generative bars: slow interfering waves, 0..12 lit cells
    function genBar(t, c) {
        return 6.2 + 3.2 * Math.sin(t * 0.9 + c * 0.45)
                   + 2.0 * Math.sin(t * 0.37 - c * 0.23 + 1.3)
                   + 1.1 * Math.sin(t * 1.7 + c * 1.1);
    }
    // generative VU rows: 0..15 lit pipes
    function genPipe(t, r) {
        return 9 + 4 * Math.sin(t * (0.8 + 0.27 * r) + r * 1.9) + 2 * Math.sin(t * 2.3 + r);
    }

    // 0 = own animation, 1 = external data; eases over ~1 s both ways, so
    // silence (after 3 s) fades into the generative waves and back
    property real ext: 0
    property var extBars: new Array(26).fill(0)
    property var extPipes: [0, 0, 0, 0]
    property var barHeights: new Array(26).fill(0)
    property var pipeLevels: [9, 9, 9, 9]

    // `force`: also for stopped elements (the first pose, e.g. when starting paused)
    function updateLevels(dt, force) {
        const have = levelsSource > 0 && levels.length >= 30;
        if (have) {
            // light loads would show nothing: system bars use a square-root scale
            const sys = levelsSource === 2;
            extBars = levels.slice(0, 26).map(v => sys ? Math.sqrt(v) : v);
            extPipes = levels.slice(26, 30);
        }
        ext = Math.max(0, Math.min(1, ext + (have ? dt : -dt)));
        const k = ext, bt = barsT.t, pt = pipesT.t;
        if (runBars || force) {
            const out = new Array(26);
            for (let c = 0; c < 26; c++)
                out[c] = Math.max(0, Math.min(12, Math.round((1 - k) * genBar(bt, c) + k * 12 * extBars[c])));
            if (out.some((v, i) => v !== barHeights[i]))
                barHeights = out;
        }
        if (runPipes || force) {
            const out = [];
            for (let r = 0; r < 4; r++)
                out.push(Math.max(k > 0.5 ? 0 : 1, Math.min(15, Math.round((1 - k) * genPipe(pt, r) + k * 15 * extPipes[r]))));
            if (out.some((v, i) => v !== pipeLevels[i]))
                pipeLevels = out;
        }
    }
    Component.onCompleted: updateLevels(0, true)

    readonly property color bgColor: "#0a0a0a"
    readonly property color ink: "#e8e0d0"
    readonly property color dim: "#5c5a54"
    readonly property color off: "#201f1e"
    readonly property color unlit: "#2e2d2a"

    // galaxy frame (reference px, edges halfway between dots)
    readonly property rect frame: Qt.rect(1180, 260, 1280, 1080)

    color: bgColor

    DotLayer {
        anchors.fill: parent
        s: scene.s
        ox: scene.ox
        oy: scene.oy
        lineColor: "#111111"
        dotColor: "#3a3935"
    }

    // animated galaxy from the C++ backend; static Canvas if the backend is
    // missing or Qt Quick runs its software renderer (no geometry nodes there)
    Loader {
        id: galaxy
        source: scene.GraphicsInfo.api === GraphicsInfo.Software ? "Galaxy.qml" : "GalaxyLive.qml"
        onStatusChanged: if (status === Loader.Error) source = "Galaxy.qml"
    }
    Binding { target: galaxy.item; property: "s"; value: scene.s; when: galaxy.item }
    Binding { target: galaxy.item; property: "ox"; value: scene.ox; when: galaxy.item }
    Binding { target: galaxy.item; property: "oy"; value: scene.oy + scene.dy * scene.s; when: galaxy.item }
    Binding { target: galaxy.item; property: "cx"; value: scene.frame.x + scene.frame.width / 2; when: galaxy.item }
    Binding { target: galaxy.item; property: "cy"; value: scene.frame.y + scene.frame.height / 2; when: galaxy.item }
    // the galaxy moves less than a pixel per frame: galaxyHz updates/s at any fps
    readonly property real galaxyStep: Math.max(1, Math.min(galaxyHz, fps))
    Binding { target: galaxy.item; property: "time"; value: Math.floor(galaxyT.t * scene.galaxyStep) / scene.galaxyStep; when: galaxy.item }
    Binding { target: galaxy.item; property: "stars"; value: scene.galaxyStars; when: galaxy.item }
    Binding { target: galaxy.item; property: "twinkle"; value: scene.galaxyTwinkle; when: galaxy.item }
    Binding { target: galaxy.item; property: "pulse"; value: scene.galaxyPulse; when: galaxy.item }

    Item {
        id: ref
        x: scene.ox
        y: scene.oy + scene.dy * scene.s
        width: 2560
        height: 1600
        scale: scene.s
        transformOrigin: Item.TopLeft

        Label {
            cy: 140
            text: "ENVIRON CTR | DR-5 |"
            color: scene.ink; bg: scene.bgColor
        }

        // VU rows: the unlit glyphs are static text; the lit pipes are plain
        // rectangles over them (changing a colour is far cheaper than
        // re-laying out text every frame)
        TextMetrics { id: pipeM; font.family: "JetBrains Mono"; font.pixelSize: 52; text: "|" }
        Repeater {
            model: 4
            Item {
                id: pipeRow
                required property int index
                readonly property real cy: 260 + 80 * index
                Label {
                    cy: pipeRow.cy
                    anchor: "ink"
                    text: "|||||||||||||||"
                    size: 52; bold: false
                    color: scene.unlit; bg: scene.bgColor
                }
                Repeater {
                    model: 15
                    Rectangle {
                        required property int index
                        width: pipeM.tightBoundingRect.width
                        height: pipeM.tightBoundingRect.height
                        x: 140 + 40 * index - width / 2
                        y: pipeRow.cy - height / 2
                        color: index < scene.pipeLevels[pipeRow.index] ? scene.ink : scene.unlit
                    }
                }
            }
        }

        // 26 x 12 cells, one per grid cell, the dots show in the gaps.
        // A frame only recolours cells (no clipping, no items added or
        // removed), so the renderer keeps its batches.
        Item {
            x: 126; y: 566
            Repeater {
                model: 26
                Item {
                    id: col
                    required property int index
                    readonly property int level: Math.max(0, Math.min(12, scene.barHeights[index] || 0))
                    x: index * 40
                    Repeater {
                        model: 12
                        Rectangle {
                            required property int index
                            y: (11 - index) * 40
                            width: 28; height: 28
                            color: index < col.level ? scene.ink : scene.off
                        }
                    }
                }
            }
        }

        Repeater {
            model: ["J", "M", "I"]
            Label {
                required property int index
                required property string modelData
                cx0: 120
                cy: 1120 + 80 * index
                anchor: "dot"
                boxInk: false
                text: ".".repeat(scene.markers[index]) + modelData + ".".repeat(25 - scene.markers[index])
                size: 50; bold: false
                color: scene.ink; bg: scene.bgColor
            }
        }

        Label {
            cy: 1380
            text: scene.clockText
            family: scene.clockFont
            color: scene.ink; bg: scene.bgColor
        }

        Label {
            cx0: scene.frame.x + 30
            cy: scene.frame.y + 40
            pitch: 20
            text: "PHI 096  VEL 228KM/S  SECTOR 1-81"
            size: 26; bold: false
            color: scene.dim; bg: scene.bgColor
        }
        Label {
            cx0: scene.frame.x + 30
            cy: scene.frame.y + scene.frame.height - 40
            pitch: 20
            text: "REDSHIFT Z=0.03  DEC -05  OBJ 22 0A8863"
            size: 26; bold: false
            color: scene.dim; bg: scene.bgColor
        }

        // corner brackets around the galaxy
        Repeater {
            model: [[0, 0, 1, 1], [1, 0, -1, 1], [0, 1, 1, -1], [1, 1, -1, -1]]
            Item {
                required property var modelData
                x: scene.frame.x + modelData[0] * scene.frame.width
                y: scene.frame.y + modelData[1] * scene.frame.height
                Rectangle { color: scene.dim; height: 3; width: 70; x: modelData[2] > 0 ? -1 : -69; y: -1 }
                Rectangle { color: scene.dim; width: 3; height: 70; y: modelData[3] > 0 ? -1 : -69; x: -1 }
            }
        }
    }
}
