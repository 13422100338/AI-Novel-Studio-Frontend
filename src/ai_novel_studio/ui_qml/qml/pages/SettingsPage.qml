import QtQuick
import QtQuick.Layouts
import "../components"

Item {
    id: root
    objectName: "settingsPage"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Text {
            text: "设置"
            font.pixelSize: 17
            font.bold: true
            color: Theme.tokens.color.textPrimary
        }

        EmptyState {
            anchors.centerIn: parent
            title: "设置工作区"
            body: "API、模型、外观、语言、快捷键与备份将在后续 Wave 接入。"
        }
    }
}
