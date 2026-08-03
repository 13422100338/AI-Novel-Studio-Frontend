import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: 56

    Rectangle {
        anchors.fill: parent
        color: Theme.tokens.color.bgSurface
        border.color: Theme.tokens.color.border
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 4

        Item {
            Layout.preferredHeight: 8
        }

        Repeater {
            model: [
                { id: "writing", icon: "\u270E", label: "写作" },
                { id: "library", icon: "\u25A4", label: "记忆库" },
                { id: "advanced", icon: "\u2726", label: "高级创作" },
                { id: "settings", icon: "\u2699", label: "设置" }
            ]
            delegate: IconButton {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 48
                Layout.alignment: Qt.AlignHCenter
                objectName: "nav-" + modelData.id
                iconText: modelData.icon
                text: modelData.label
                selected: Facade.activeNav === modelData.id
                onClicked: Facade.setActiveNav(modelData.id)
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
