import QtQuick
import QtQuick.Window
import "../plugin/org.dotgrid.live/contents/ui"

// Dev stand: runs the wallpaper composition outside plasmashell.
//   qml6 dev/host.qml -- --mode=night --size=1766x1104 --inset=44
//   qml6 dev/host.qml -- --mode=day --size=2560x1600 --shot=docs/shots/day.png
//   qml6 dev/host.qml -- --paused=1 --off=galaxy,life
//   qml6 dev/host.qml -- --galaxy-turn=1 --life-rate=6
// Qt logs go to journald by default; add QT_FORCE_STDERR_LOGGING=1 to see them.
// Keys: D day, N night, P pause, S screenshot, Q quit.
Window {
    id: win

    function arg(name, def) {
        for (const a of Qt.application.arguments)
            if (a.startsWith("--" + name + "="))
                return a.slice(name.length + 3);
        return def;
    }
    readonly property var size: arg("size", "1766x1104").split("x").map(Number)
    readonly property string shot: arg("shot", "")

    width: size[0]
    height: size[1]
    visible: true
    title: "DotGrid Live dev"

    Composition {
        id: comp
        anchors.fill: parent
        focus: true
        mode: win.arg("mode", "night")
        fps: Number(win.arg("fps", "15"))
        clockFont: win.arg("font", "JetBrains Mono")
        bottomInset: Number(win.arg("inset", "0"))
        paused: win.arg("paused", "0") === "1"
        // --live=0: ignore dotgrid-livectl / live.json (fixed scenarios for shots and measurements)
        useLive: win.arg("live", "1") === "1"
        // --static=1: the fallback PNG (no clocks, nothing moving)
        staticImage: win.arg("static", "0") === "1"
        galaxyTurnMinutes: Number(win.arg("galaxy-turn", "4"))
        lifeRate: Number(win.arg("life-rate", "2.5"))
        lifeMode: win.arg("life-mode", "random")
        // --off=bars,life switches elements off
        elements: {
            const e = {};
            for (const n of win.arg("off", "").split(",").filter(x => x))
                e[n] = false;
            return e;
        }

        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_D) comp.mode = "day";
            else if (e.key === Qt.Key_N) comp.mode = "night";
            else if (e.key === Qt.Key_P) comp.paused = !comp.paused;
            else if (e.key === Qt.Key_S) win.save("docs/shots/dev-" + comp.mode + ".png", false);
            else if (e.key === Qt.Key_Q) Qt.quit();
        }
    }

    function save(path, quit) {
        comp.grabToImage((r) => {
            console.log(r.saveToFile(path) ? "saved " + path : "FAILED " + path);
            if (quit) Qt.quit();
        });
    }

    // --switch=day:1500  change mode after N ms (to look at the cross-fade)
    Timer {
        running: win.arg("switch", "") !== ""
        interval: Number(win.arg("switch", ":0").split(":")[1])
        onTriggered: comp.mode = win.arg("switch", "").split(":")[0]
    }

    Timer {
        running: win.shot !== ""
        interval: Number(win.arg("delay", "1500"))
        onTriggered: win.save(win.shot, true)
    }
}
