import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property alias cfg_dotMode: mode.currentIndex
    property alias cfg_showTotal: total.checked

    QQC2.ComboBox {
        id: mode
        Kirigami.FormData.label: i18n("Layout:")
        model: [i18n("Automatic"), i18n("A column per sensor"), i18n("History")]
    }
    QQC2.CheckBox {
        id: total
        Kirigami.FormData.label: i18n("Total:")
        text: i18n("Show the total as text")
    }
}
