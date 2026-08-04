import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string label: ""
    property string preview: ""
    signal cleared()

    implicitHeight: 28
    radius: Theme.tokens.radius.r8
    color: Theme.tokens.color.bgSidebar
    border.color: Theme.tokens.color.accent
    border.width: 1

    // Prevent a jarring pop-in: the chip fades in/out when a selection
    // reference appears or is cleared. Occasional frequency, ease-out.
    Behavior on opacity {
        NumberAnimation {
            duration: Facade.reduceMotion ? 0 : 150
            easing.type: Easing.OutCubic
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 4
        spacing: 6

        Text {
            Layout.fillWidth: true
            text: "已引用 · " + root.label
            font.pixelSize: 11
            elide: Text.ElideRight
            color: Theme.tokens.color.textPrimary
        }
        Text {
            visible: root.preview !== ""
            text: root.preview
            font.pixelSize: 10
            elide: Text.ElideRight
            color: Theme.tokens.color.textSecondary
        }
        AppButton {
            text: "×"
            implicitWidth: 24
            implicitHeight: 22
            onClicked: root.cleared()
        }
    }
}
