import QtQuick

// Galaxy as in make_desktop.py: axis-aligned squares of different size and
// brightness, scattered over a flattened, tilted disc. Painted once into a
// texture; the animated version will move the same star list.
Canvas {
    id: galaxy

    property real s: 1              // reference px -> item px
    property real ox: 0             // item px offset of the reference frame
    property real oy: 0
    property real cx: 1760          // centre, reference px
    property real cy: 760
    property real radius: 330       // sigma of the radial distribution
    property real flatten: 0.33
    property real tilt: -0.38
    property int stars: 2600
    property real time: 0           // unused: this static version does not move
    property bool twinkle: true     // same API as GalaxyLive.qml; no effect here
    property bool pulse: true
    onStarsChanged: requestPaint()

    // painted area in reference px (the frame and right of it); stars outside are clipped
    readonly property rect area: Qt.rect(1180, 100, 1380, 1400)

    x: ox + area.x * s
    y: oy + area.y * s
    width: Math.ceil(area.width * s)
    height: Math.ceil(area.height * s)
    renderStrategy: Canvas.Immediate

    function rng(seed) {   // mulberry32, deterministic layout
        let a = seed >>> 0;
        return function () {
            a = (a + 0x6D2B79F5) >>> 0;
            let t = a;
            t = Math.imul(t ^ (t >>> 15), t | 1);
            t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
    }

    // [r, theta, size, grey]; same distribution as the PNG generator
    readonly property var starList: {
        const rnd = rng(11), out = [];
        const big = [5, 7, 9, 11], small = [3, 4, 5];
        for (let i = 0; i < stars; i++) {
            const t = rnd() * 2 * Math.PI;
            const u1 = Math.max(1e-9, rnd()), u2 = rnd();
            const rr = Math.abs(Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2)) * radius;
            const sz = rr < 140 ? big[Math.floor(rnd() * 4)] : small[Math.floor(rnd() * 3)];
            out.push([rr, t, sz, Math.max(40, Math.round(245 - rr * 0.55))]);
        }
        return out;
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const k = s, x0 = area.x, y0 = area.y;
        let last = -1;
        for (const st of starList) {
            const dx = st[0] * Math.cos(st[1]);
            const px = cx + dx;
            const py = cy + st[0] * Math.sin(st[1]) * flatten + dx * tilt;
            const g = st[3];
            if (g !== last) {
                ctx.fillStyle = Qt.rgba(g / 255, (g - 6) / 255, (g - 18) / 255, 1);
                last = g;
            }
            // snap to whole pixels so the squares stay crisp
            const sz = Math.max(1, Math.round(st[2] * k));
            ctx.fillRect(Math.round((px - x0) * k), Math.round((py - y0) * k), sz, sz);
        }
    }
}
