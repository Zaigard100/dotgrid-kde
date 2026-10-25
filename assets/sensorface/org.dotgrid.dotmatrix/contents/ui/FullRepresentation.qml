import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.faces as Faces

// Popup and desktop: title, a larger dot chart and the values as text.
Faces.SensorFace {
    id: root
    Layout.minimumWidth: Kirigami.Units.gridUnit * 8

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.controller.title
            visible: root.controller.showTitle && text.length > 0
            level: 3
        }
        DotChart {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 3
            Layout.preferredHeight: Kirigami.Units.gridUnit * 5
            pitch: 7
            sensorIds: root.controller.highPrioritySensorIds
            mode: root.controller.faceConfiguration.dotMode
            updateRateLimit: root.controller.updateRateLimit
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: 0
            Repeater {
                model: root.controller.totalSensors.concat(root.controller.highPrioritySensorIds)
                delegate: RowLayout {
                    Layout.fillWidth: true
                    Sensors.Sensor {
                        id: sensor
                        sensorId: modelData
                        updateRateLimit: root.controller.updateRateLimit
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: root.controller.sensorLabels[modelData] || sensor.shortName || sensor.name
                        color: Kirigami.Theme.disabledTextColor
                    }
                    QQC2.Label {
                        text: sensor.formattedValue
                        font: Kirigami.Theme.fixedWidthFont
                    }
                }
            }
        }
    }
}
