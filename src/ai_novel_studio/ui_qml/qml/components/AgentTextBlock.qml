import QtQuick

Rectangle {
    id: root
    objectName: "agentTextBlock"

    property string text: ""
    property bool user: false
    property color textColor: root.user
        ? "white"
        : Theme.tokens.color.textPrimary

    implicitHeight: Math.max(28, body.implicitHeight + 14)
    width: parent ? parent.width : 320
    radius: Theme.tokens.radius.r12
    color: root.user ? Theme.tokens.color.accent : Theme.tokens.color.bgSidebar
    border.color: Theme.tokens.color.border
    border.width: root.user ? 0 : 1

    Text {
        id: body
        anchors.fill: parent
        anchors.margins: 8
        text: root.text
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        color: root.textColor
    }
}
