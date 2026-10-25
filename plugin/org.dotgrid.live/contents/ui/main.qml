import QtQuick
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    // "auto" follows the KDE colour scheme that dotgrid-theme applies:
    // DotGridNight has a dark window background, DotGridDay a light one.
    SystemPalette { id: palette; colorGroup: SystemPalette.Active }
    readonly property bool paletteDark: palette.window.hslLightness < 0.5
    readonly property string mode: {
        const m = root.configuration.Mode;
        return m === "day" || m === "night" ? m : (paletteDark ? "night" : "day");
    }

    // Panels: the containment knows the free area of this screen.
    // undefined for a moment while the containment starts up
    readonly property rect freeRect: Plasmoid.availableScreenRect ?? Qt.rect(0, 0, 0, 0)
    readonly property real topInset: freeRect.height > 0 ? Math.max(0, freeRect.y) : 0
    readonly property real bottomInset: freeRect.height > 0
        ? Math.max(0, height - (freeRect.y + freeRect.height)) : 0

    Composition {
        anchors.fill: parent
        mode: root.mode
        paused: root.configuration.Paused
        fps: root.configuration.Fps
        clockFont: root.configuration.ClockFont
        clockBottomMargin: root.configuration.ClockBottomMargin
        galaxyTurnMinutes: root.configuration.GalaxyTurnMinutes
        lifeRate: root.configuration.LifeRate
        lifeMode: root.configuration.LifeMode
        elements: ({
            galaxy: root.configuration.ElementGalaxy,
            bars: root.configuration.ElementBars,
            pipes: root.configuration.ElementPipes,
            markers: root.configuration.ElementMarkers,
            matrix: root.configuration.ElementMatrix,
            life: root.configuration.ElementLife,
            tiles: root.configuration.ElementTiles,
            battery: root.configuration.ElementBattery
        })
        topInset: root.topInset
        bottomInset: root.bottomInset
    }
}
