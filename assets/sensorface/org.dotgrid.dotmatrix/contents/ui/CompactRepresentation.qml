import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import org.kde.ksysguard.faces as Faces

// Panel: the total as text (when there is a total sensor) and the dot chart.
Faces.CompactSensorFace {
    id: root

    readonly property bool showTotal: controller.faceConfiguration.showTotal && controller.totalSensors.length > 0

    Layout.minimumWidth: horizontalFormFactor ? row.implicitWidth : defaultMinimumSize
    Layout.preferredWidth: horizontalFormFactor ? row.implicitWidth : -1
    Layout.maximumWidth: horizontalFormFactor ? row.implicitWidth : -1

    contentItem: RowLayout {
        id: row
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            visible: root.showTotal
            text: total.formattedValue
            font: Kirigami.Theme.fixedWidthFont
            color: Kirigami.Theme.textColor
            Layout.alignment: Qt.AlignVCenter
            Sensors.Sensor {
                id: total
                sensorId: root.controller.totalSensors[0] || ""
                updateRateLimit: root.controller.updateRateLimit
            }
        }
        DotChart {
            Layout.fillHeight: true
            Layout.preferredWidth: implicitWidth
            sensorIds: root.controller.highPrioritySensorIds
            mode: root.controller.faceConfiguration.dotMode
            updateRateLimit: root.controller.updateRateLimit
        }
    }
}
