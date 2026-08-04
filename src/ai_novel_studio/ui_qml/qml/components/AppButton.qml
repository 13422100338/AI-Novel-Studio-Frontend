import QtQuick

Rectangle {
    id: root

    property string text: ""
    property bool primary: false
    property bool selected: false
    signal clicked()

    implicitHeight: 32
    implicitWidth: label.implicitWidth + 20
    radius: Theme.tokens.radius.r8
    border.width: 1
    border.color: root.primary ? Theme.tokens.color.accent : Theme.tokens.color.border
    color: !root.enabled ? Theme.tokens.color.bgSidebar
         : root.selected ? Theme.tokens.color.accent
         : root.primary ? Theme.tokens.color.accent
         : Theme.tokens.color.bgSurface
    opacity: root.enabled ? 1.0 : 0.5
    // Press feedback: respond on pointer-down, subtle and near-imperceptible
    // (Tens/day frequency tier). Ease-out starts fast so the press feels
    // immediate, not delayed.
    scale: mouseArea.pressed ? 0.97 : 1.0

    Behavior on color {
        ColorAnimation {
            duration: Facade.reduceMotion ? 0 : Theme.tokens.duration.fast
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Facade.reduceMotion ? 0 : 120
            easing.type: Easing.OutCubic
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 12
        color: root.primary || root.selected ? "white" : Theme.tokens.color.textPrimary
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
