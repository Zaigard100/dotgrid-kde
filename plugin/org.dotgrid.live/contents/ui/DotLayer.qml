import QtQuick

// Static background: line grid + dot grid. Painted once per size change,
// afterwards it is a plain texture and costs nothing per frame.
Canvas {
    id: layer

    property real s: 1                       // reference px -> item px
    property real ox: 0                      // item px origin of the reference frame;
    property real oy: 0                      // the grid stays locked to the content
    property color lineColor: "#111111"
    property color dotColor: "#3a3935"
    // dots keep this distance from the screen edges (reference px)
    property real dotMargin: 80
    property real dotBottom: 120

    renderStrategy: Canvas.Immediate
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onSChanged: requestPaint()
    onOxChanged: requestPaint()
    onOyChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onDotColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const step = 40 * s;
        const fx = ((ox % step) + step) % step, fy = ((oy % step) + step) % step;
        ctx.reset();
        ctx.fillStyle = lineColor;
        for (let x = fx; x < width; x += step)
            ctx.fillRect(Math.round(x), 0, Math.max(1, s), height);
        for (let y = fy; y < height; y += step)
            ctx.fillRect(0, Math.round(y), width, Math.max(1, s));

        ctx.fillStyle = dotColor;
        const r = 3 * s, eps = 0.5;
        const x0 = dotMargin * s - eps, x1 = width - dotMargin * s + eps;
        const y0 = dotMargin * s - eps, y1 = height - dotBottom * s + eps;
        ctx.beginPath();
        for (let y = fy; y <= y1; y += step) {
            if (y < y0)
                continue;
            for (let x = fx; x <= x1; x += step) {
                if (x < x0)
                    continue;
                ctx.moveTo(x + r, y);
                ctx.arc(x, y, r, 0, 2 * Math.PI);
            }
        }
        ctx.fill();
    }
}
