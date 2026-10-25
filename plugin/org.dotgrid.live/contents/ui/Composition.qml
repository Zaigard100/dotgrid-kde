import QtQuick

// The whole wallpaper, independent of Plasma so the dev host can load it.
Item {
    id: comp

    // These are the fallbacks (plugin config / dev host). The state from
    // dotgrid-livectl, or ~/.config/dotgrid/live.json without it, wins.
    property string mode: "night"        // resolved mode: day | night
    property bool paused: false
    property int fps: 15
    property var elements: ({})
    property string bigDigitsSource: "battery"   // battery | none
    property real galaxyTurnMinutes: 4    // minutes per turn of the galaxy's outer edge
    property real lifeRate: 2.5           // Life generations per second
    property string lifeMode: "random"    // random | edges | draw
    property bool useLive: true
    // static fallback PNG (lock screen): no clocks, so no frozen time in it
    property bool staticImage: false

    Loader {
        id: liveSource
        active: comp.useLive
        source: "LiveSource.qml"
    }
    readonly property var st: liveSource.item ? liveSource.item.status : ({})
    function pick(key, fallback) { return st[key] !== undefined && st[key] !== null ? st[key] : fallback; }

    readonly property string xMode: {
        const m = st.daemon ? st.effective_mode : st.mode;
        return m === "day" || m === "night" ? m : mode;
    }
    readonly property bool xPaused: st.daemon ? !!st.effective_paused : pick("paused", paused)
    // fps may be one number (old configs, dev host) or {day, night}
    readonly property var xFpsAll: pick("fps", fps)
    readonly property int xFpsNight: typeof xFpsAll === "object" ? xFpsAll.night : xFpsAll
    readonly property int xFpsDay: typeof xFpsAll === "object" ? xFpsAll.day : xFpsAll
    // per-element details; missing keys fall back to the defaults below
    readonly property var xOpts: pick("opts", ({}))
    function opt(el, key, def) {
        const o = xOpts[el];
        return o && o[key] !== undefined ? o[key] : def;
    }
    readonly property var xElements: pick("elements", elements)
    readonly property real xGalaxyTurn: pick("galaxy_turn_minutes", galaxyTurnMinutes)
    readonly property real xLifeRate: pick("life_rate", lifeRate)
    readonly property string xLifeMode: pick("life_mode", lifeMode)
    readonly property string xBars: pick("bars", "audio")

    // Elements that can be switched off one by one. A switched-off element
    // freezes in its current pose and its timers stop.
    function on(name) { return xElements[name] !== false; }
    // animation runs only if the element is on and nothing is paused;
    // the clocks and J/M/I (they show time) ignore the pause
    function run(name) { return !xPaused && on(name); }
    property string clockFont: "JetBrains Mono"
    property real topInset: 0             // item px taken by panels at the top
    property real bottomInset: 0          // item px taken by panels at the bottom
    property real clockBottomMargin: 40   // reference px kept free above the panel

    // reference composition is 2560x1600; keep it proportional on any aspect
    readonly property real s: Math.min(width / 2560, height / 1600)
    readonly property real ox: (width - 2560 * s) / 2
    readonly property real oy: (height - 1600 * s) / 2

    // Both scenes occupy rows 100..1420 of the reference frame. Centre that
    // block in the area the panels leave free, in whole grid steps so the
    // content stays on the dots, and never let it reach under a panel.
    readonly property real contentTop: 100
    readonly property real contentBottom: 1420
    readonly property real freeTop: (topInset - oy) / s
    readonly property real freeBottom: (height - bottomInset - oy) / s
    readonly property real dy: {
        const centred = 40 * Math.round(((freeTop + freeBottom) - (contentTop + contentBottom)) / 2 / 40);
        const lowest = 40 * Math.floor((freeBottom - clockBottomMargin - contentBottom) / 40);
        return Math.min(centred, lowest);
    }

    // ---- clocks: 1 Hz, aligned to the second, independent of pause ----
    property date now: new Date()
    function pad(n) { return n < 10 ? "0" + n : "" + n; }
    readonly property string hms: pad(now.getHours()) + ":" + pad(now.getMinutes()) + ":" + pad(now.getSeconds())
    readonly property string unixLine: Math.floor(now.getTime() / 1000) + " | " + hms

    Timer {
        id: tick
        running: true
        repeat: false
        interval: 1000 - (Date.now() % 1000) + 2
        onTriggered: {
            comp.now = new Date();
            interval = 1000 - (Date.now() % 1000) + 2;
            start();
        }
    }

    // J / M / I as a clock on the dot rows: J hour of the day, M minute of
    // the hour, I second of the minute; 26 positions per row
    property var markers: [9, 11, 1]
    // the 12 tiles fill up over each minute
    property real progress: 0
    onNowChanged: {
        if (staticImage)
            return;           // J/M/I and tiles would freeze a moment of time
        if (on("markers")) {
            const h = now.getHours(), m = now.getMinutes(), sec = now.getSeconds();
            markers = [Math.floor((h + m / 60) / 24 * 26),
                       Math.floor((m + sec / 60) / 60 * 26),
                       Math.floor(sec / 60 * 26)];
        }
        if (run("tiles")) {
            const h = now.getHours(), m = now.getMinutes(), sec = now.getSeconds();
            const src = opt("tiles", "source", "minute");
            progress = src === "hour" ? (m * 60 + sec + 1) / 3600
                     : src === "day" ? (h * 3600 + m * 60 + sec + 1) / 86400
                     : (sec + 1) / 60;
        }
    }

    Component.onCompleted: nowChanged()

    // battery for the big digits; absent backend -> "--"
    Loader {
        id: battery
        source: "BatterySource.qml"
        active: comp.on("battery") && comp.bigDigitsSource === "battery"
    }
    property string bigDigits: "--"
    Binding {
        target: comp
        property: "bigDigits"
        when: battery.status === Loader.Ready
        value: battery.item && battery.item.percent >= 0
               ? (battery.item.percent >= 100 ? "FL" : comp.pad(battery.item.percent)) : "--"
        restoreMode: Binding.RestoreNone
    }

    // ---- scenes: only the visible one is loaded; cross-fade on switch ----
    Loader {
        id: night
        anchors.fill: parent
        active: comp.xMode === "night" || opacity > 0
        opacity: comp.xMode === "night" ? 1 : 0
        // fade the scene as one picture; without a layer every element would
        // turn translucent on its own and the text boxes would show through
        layer.enabled: opacity > 0 && opacity < 1
        Behavior on opacity { NumberAnimation { duration: 1500 } }
        sourceComponent: NightScene {
            s: comp.s
            ox: comp.ox
            oy: comp.oy
            dy: comp.dy
            clockFont: comp.clockFont
            clockText: comp.staticImage ? "16592170 | 60190813" : comp.unixLine
            fps: comp.xFpsNight
            galaxyStars: comp.opt("galaxy", "stars", 2600)
            galaxyTwinkle: comp.opt("galaxy", "twinkle", true)
            galaxyPulse: comp.opt("galaxy", "pulse", true)
            galaxyHz: comp.opt("galaxy", "hz", 10)
            barsSpeed: comp.opt("bars", "speed", 1)
            pipesSpeed: comp.opt("pipes", "speed", 1)
            runGalaxy: comp.run("galaxy")
            runBars: comp.run("bars")
            runPipes: comp.run("pipes")
            galaxyTurnMinutes: comp.xGalaxyTurn
            markers: comp.markers
            levelsSource: liveSource.item && comp.xBars !== "generative" ? liveSource.item.levelsSource : 0
            levels: liveSource.item ? liveSource.item.levels : []
        }
    }

    Loader {
        id: day
        anchors.fill: parent
        active: comp.xMode === "day" || opacity > 0
        opacity: comp.xMode === "day" ? 1 : 0
        // fade the scene as one picture; without a layer every element would
        // turn translucent on its own and the text boxes would show through
        layer.enabled: opacity > 0 && opacity < 1
        Behavior on opacity { NumberAnimation { duration: 1500 } }
        sourceComponent: DayScene {
            s: comp.s
            ox: comp.ox
            oy: comp.oy
            dy: comp.dy
            clockFont: comp.clockFont
            clockText: comp.staticImage ? "" : comp.hms
            progress: comp.staticImage ? 1 : comp.progress
            bigDigits: comp.staticImage ? "00" : comp.bigDigits
            runLife: comp.run("life")
            runMatrix: comp.run("matrix")
            lifeRate: comp.xLifeRate
            lifeMode: comp.xLifeMode
            lifeDensity: comp.opt("life", "density", 16)
            lifeWarmup: comp.opt("life", "warmup", 12)
            lifeStaleLimit: comp.opt("life", "stale", 30)
            matrixInterval: comp.opt("matrix", "interval", 1.4)
            matrixColumnEvery: comp.opt("matrix", "column_every", 18)
            matrixFlicker: comp.opt("matrix", "flicker", 6)
            fps: comp.xFpsDay
        }
    }
}
