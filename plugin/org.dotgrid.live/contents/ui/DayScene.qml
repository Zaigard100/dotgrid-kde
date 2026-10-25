import QtQuick

// Day composition on the 40 px grid: left edge 120, right edge 2440.
Rectangle {
    id: scene

    property real s: 1
    property real ox: 0
    property real oy: 0
    property real dy: 0                 // reference px, whole grid steps
    property string clockFont: "JetBrains Mono"
    property string clockText: ""
    property string bigDigits: "00"
    property real progress: 0           // 0..1, the 12-tile bar
    property bool runLife: true
    property bool runMatrix: true
    property real lifeRate: 2.5         // generations per second
    property int lifeDensity: 16        // % of cells alive in a random seed
    property int lifeWarmup: 12         // generations a new field is run ahead
    property int lifeStaleLimit: 30     // stalled generations before a reseed
    property real matrixInterval: 1.4   // s between flickers
    property int matrixColumnEvery: 18  // every Nth flicker locks a whole column; 0 = never
    property int matrixFlicker: 6       // letters per flicker
    property int fps: 15                // by day only the flicker speed follows it
    // random: whole field random, reseeded when it dies out or stalls
    // edges:  bounded field, the border keeps sparking, blobs appear inside
    // draw:   click / drag on the field places cells, never reseeded
    property string lifeMode: "random"
    property var matrixRows: ["TIXLZWXUQ", "AOYHUBFDL", "PHMRDSHAX", "GNIFYMFYZ", "CETTOEEAA",
                              "GYGFFJKGR", "VUGFWGMJA", "LNFEICKJT", "SATVWKCJL"]

    // Life field = these grid dots (reference px); a live cell replaces its dot
    readonly property int fieldX: 120
    readonly property int fieldY: 320
    readonly property int fieldCols: 47     // x 120..1960
    readonly property int fieldRows: 28     // y 320..1400

    readonly property color bgColor: "#d6cdbc"
    readonly property color ink: "#161614"
    readonly property color tile: "#a09888"

    color: bgColor

    // ---- Game of Life on the dot grid ----
    // live cell "0", newborn "i", dead = the plain dot. Only cells that change
    // are touched. Cells switch instantly: one redraw per generation.
    property var life: new Uint8Array(fieldCols * fieldRows)   // 0 dead, 1 alive, 2 newborn
    property var lifeBack: new Uint8Array(fieldCols * fieldRows)
    property var lifePrev2: new Uint8Array(fieldCols * fieldRows)
    property int lifeStale: 0
    property int lifeGen: 0
    readonly property bool lifeWrap: lifeMode === "random"     // torus only in random mode

    // A fresh field is evolved for a while before it is shown, so even a
    // frozen field (element off) is a real Life state with "0" and "i".

    onLifeModeChanged: lifeSeed()

    function lifeSeed() {
        const n = fieldCols * fieldRows;
        let cur = new Uint8Array(n), nxt = new Uint8Array(n);
        if (lifeMode === "random") {
            for (let i = 0; i < n; i++)
                cur[i] = Math.random() < lifeDensity / 100 ? 1 : 0;
        } else if (lifeMode === "edges") {
            lifeSparkEdges(cur, 2, 0.35);
            lifeBlob(cur, 0.45);
            lifeBlob(cur, 0.45);
        }
        if (lifeMode !== "draw") {
            for (let g = 0; g < lifeWarmup; g++) {
                lifeNext(cur, nxt);
                if (lifeMode === "edges")
                    lifeSparkEdges(nxt, 1, 0.25);
                [cur, nxt] = [nxt, cur];
            }
        }
        for (let i = 0; i < n; i++)
            lifeSet(i, cur[i]);
        lifePrev2.fill(0);
        lifeStale = 0;
    }
    // random live cells in the outer `depth` rings of the field
    function lifeSparkEdges(a, depth, p) {
        const W = fieldCols, H = fieldRows;
        for (let y = 0; y < H; y++)
            for (let x = 0; x < W; x++)
                if ((x < depth || y < depth || x >= W - depth || y >= H - depth) && Math.random() < p)
                    a[y * W + x] = a[y * W + x] || 2;
    }
    // a random 5x5 patch somewhere in the middle half of the field
    function lifeBlob(a, p) {
        const W = fieldCols, H = fieldRows;
        const x0 = Math.floor(W / 4 + Math.random() * (W / 2 - 5));
        const y0 = Math.floor(H / 4 + Math.random() * (H / 2 - 5));
        for (let y = y0; y < y0 + 5; y++)
            for (let x = x0; x < x0 + 5; x++)
                if (Math.random() < p)
                    a[y * W + x] = a[y * W + x] || 2;
    }
    function lifeSet(i, v) {
        if (life[i] === v)
            return;
        life[i] = v;
        const cell = lifeCells.itemAt(i);
        if (cell)
            cell.state = v;
    }
    // one generation from cur into nxt; returns the live count.
    // random mode wraps around (torus), the others treat outside as dead
    function lifeNext(cur, nxt) {
        const W = fieldCols, H = fieldRows, wrap = lifeWrap;
        const at = (x, y) => {
            if (wrap)
                return cur[((y + H) % H) * W + (x + W) % W] > 0;
            return x >= 0 && y >= 0 && x < W && y < H && cur[y * W + x] > 0;
        };
        let alive = 0;
        for (let y = 0; y < H; y++) {
            for (let x = 0; x < W; x++) {
                const k = at(x - 1, y - 1) + at(x, y - 1) + at(x + 1, y - 1)
                        + at(x - 1, y) + at(x + 1, y)
                        + at(x - 1, y + 1) + at(x, y + 1) + at(x + 1, y + 1);
                const was = cur[y * W + x] > 0;
                const now = was ? (k === 2 || k === 3) : k === 3;
                nxt[y * W + x] = now ? (was ? 1 : 2) : 0;
                alive += now;
            }
        }
        return alive;
    }
    function lifeStep() {
        const n = fieldCols * fieldRows, cur = life, nxt = lifeBack;
        let alive = lifeNext(cur, nxt);
        lifeGen++;
        if (lifeMode === "edges") {
            lifeSparkEdges(nxt, 1, 0.12);
            if (lifeGen % 24 === 0)
                lifeBlob(nxt, 0.45);
        }
        let changed = 0, same2 = true;
        for (let i = 0; i < n; i++) {
            if ((nxt[i] > 0) !== (cur[i] > 0))
                changed++;
            if ((nxt[i] > 0) !== (lifePrev2[i] > 0))
                same2 = false;
        }
        for (let i = 0; i < n; i++) {
            lifePrev2[i] = cur[i];
            lifeSet(i, nxt[i]);
        }
        // still life or a period-2 blinker field counts as stagnation
        lifeStale = (changed === 0 || same2) ? lifeStale + 1 : 0;
        if (lifeMode === "random" && (alive < 6 || lifeStale > lifeStaleLimit))
            lifeSeed();
    }
    // draw mode: a click or drag makes the cell under the pointer alive
    function lifePlace(rx, ry) {
        const x = Math.round((rx - fieldX) / 40), y = Math.round((ry - fieldY) / 40);
        if (x < 0 || y < 0 || x >= fieldCols || y >= fieldRows)
            return;
        lifeSet(y * fieldCols + x, 1);
    }

    Timer {
        interval: Math.round(1000 / Math.max(0.2, scene.lifeRate))
        repeat: true
        running: scene.runLife
        onTriggered: scene.lifeStep()
    }

    // ---- letter matrix: a cell flickers through letters and settles;
    // now and then a whole column locks in from top to bottom ----
    readonly property string alphabet: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    property var scrambles: []          // {r, c, wait, left, final}

    function letter() { return alphabet[Math.floor(Math.random() * alphabet.length)]; }
    function setLetter(r, c, ch) {
        const rows = matrixRows.slice();
        rows[r] = rows[r].slice(0, c) + ch + rows[r].slice(c + 1);
        matrixRows = rows;
    }
    function scramble(r, c, wait) {
        const jobs = scrambles.slice();
        jobs.push({ r: r, c: c, wait: wait, left: Math.max(1, matrixFlicker - 1 + Math.floor(Math.random() * 3)),
                    final: letter() });
        scrambles = jobs;
    }

    Timer {   // schedules new flickers; idle in between
        interval: Math.round(1000 * scene.matrixInterval)
        repeat: true
        running: scene.runMatrix
        property int beat: 0
        onTriggered: {
            if (scene.matrixColumnEvery > 0 && ++beat % scene.matrixColumnEvery === 0) {
                const c = Math.floor(Math.random() * 9);
                for (let r = 0; r < 9; r++)
                    scene.scramble(r, c, r * 2);
            } else {
                scene.scramble(Math.floor(Math.random() * 9), Math.floor(Math.random() * 9), 0);
            }
        }
    }
    Timer {   // runs only while something flickers
        interval: Math.max(33, Math.round(1000 / Math.min(scene.fps, 30)))
        repeat: true
        running: scene.runMatrix && scene.scrambles.length > 0
        onTriggered: {
            const keep = [];
            for (const j of scene.scrambles) {
                if (j.wait > 0) {
                    j.wait--;
                } else if (j.left > 0) {
                    j.left--;
                    scene.setLetter(j.r, j.c, scene.letter());
                } else {
                    scene.setLetter(j.r, j.c, j.final);
                    continue;
                }
                keep.push(j);
            }
            scene.scrambles = keep;
        }
    }

    Component.onCompleted: lifeSeed()

    DotLayer {
        anchors.fill: parent
        s: scene.s
        ox: scene.ox
        oy: scene.oy
        lineColor: "#cdc4b3"
        dotColor: scene.ink
    }

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
            text: scene.clockText
            family: scene.clockFont
            color: scene.ink; bg: scene.bgColor
        }
        Label {
            rightEdge: 2440
            cy: 140
            text: "24556 DR 5"
            color: scene.ink; bg: scene.bgColor
        }

        // progress tiles, one per grid cell under the clock
        Repeater {
            model: 12
            Rectangle {
                required property int index
                x: 124 + index * 40; y: 204
                width: 32; height: 32
                color: scene.tile
                opacity: Math.max(0.25, Math.min(1, scene.progress * 12 - index))
            }
        }

        // 9x9 letter matrix, right-aligned; one Label per row
        Repeater {
            model: 9
            Label {
                required property int index
                rightEdge: 2440
                cy: 340 + 80 * index
                text: scene.matrixRows[index]
                size: 56
                color: scene.ink; bg: scene.bgColor
            }
        }

        Label {
            rightEdge: 2440
            cy: 1300
            pitch: 200
            text: scene.bigDigits
            family: scene.clockFont
            size: 300
            color: scene.ink; bg: scene.bgColor
        }

        // Life glyphs sit on the dots; a dead cell is just the dot.
        TextMetrics { id: glyphM; font.family: "JetBrains Mono"; font.pixelSize: 44; text: "0" }
        FontMetrics { id: glyphF; font: glyphM.font }
        readonly property real glyphDx: -glyphM.advanceWidth / 2
        readonly property real glyphDy: -(glyphM.tightBoundingRect.y + glyphM.tightBoundingRect.height / 2) - glyphF.ascent

        MouseArea {
            enabled: scene.lifeMode === "draw"
            x: scene.fieldX - 20
            y: scene.fieldY - 20
            width: scene.fieldCols * 40
            height: scene.fieldRows * 40
            acceptedButtons: Qt.LeftButton
            onPressed: (m) => scene.lifePlace(x + m.x, y + m.y)
            onPositionChanged: (m) => { if (pressed) scene.lifePlace(x + m.x, y + m.y); }
        }

        Repeater {
            id: lifeCells
            model: scene.fieldCols * scene.fieldRows
            Item {
                id: cell
                required property int index
                property int state: 0          // set by lifeSet(), not bound
                property string glyph: "0"     // keeps its glyph while fading out
                onStateChanged: if (state > 0) glyph = state === 2 ? "i" : "0"
                x: scene.fieldX + (index % scene.fieldCols) * 40
                y: scene.fieldY + Math.floor(index / scene.fieldCols) * 40
                visible: state > 0
                Rectangle {
                    x: -20; y: -20; width: 40; height: 40
                    color: scene.bgColor
                }
                Text {
                    x: ref.glyphDx
                    y: ref.glyphDy
                    text: cell.glyph
                    font: glyphM.font
                    color: scene.ink
                }
            }
        }
    }
}
