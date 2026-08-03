import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    objectName: "agentRunStatus"

    property string label: ""
    property bool busy: false
    property string status: ""

    spacing: 6

    Rectangle {
        width: 8
        height: 8
        radius: 4
        color: root.busy ? Theme.tokens.color.accent : Theme.tokens.color.success
        SequentialAnimation on color {
            running: root.busy
            loops: Animation.Infinite
            ColorAnimation { to: Theme.tokens.color.bgSidebar; duration: 400 }
            ColorAnimation { to: Theme.tokens.color.accent; duration: 400 }
        }
    }
    Text {
        text: root.busy ? root.label + "…" : root.label
        font.pixelSize: 11
        color: Theme.tokens.color.textSecondary
    }
    Text {
        text: root.status
        font.pixelSize: 10
        color: Theme.tokens.color.textSecondary
    }
}
