import QtQuick
import QtQuick.Layouts

// Resizable, docked AI Assistant panel. It is a layout cell (never overlays the
// WebEngine surface). Drag the left edge to resize, double-click to restore,
// collapse to a slim expand tab.
Item {
    id: root
    objectName: "agentDock"

    property bool open: false
    property int defaultWidth: 400
    property int minWidth: 320
    property int maxWidth: Math.max(320, Math.round(windowWidth * 0.45))
    property int windowWidth: 1440
    property int currentWidth: defaultWidth
    property bool reduceMotion: Facade.reduceMotion
    signal closed()

    Layout.preferredWidth: root.open ? root.currentWidth : 0
    Layout.fillHeight: true
    Layout.maximumWidth: root.maxWidth
    clip: true

    Rectangle {
        anchors.fill: parent
        visible: root.open
        color: Theme.tokens.color.bgSurface
        border.color: Theme.tokens.color.border
        border.width: 1

        CreativeAgentPanel {
            anchors.fill: parent
        }
    }

    Rectangle {
        id: handle
        width: 5
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        visible: root.open
        color: Theme.tokens.color.border

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeHorCursor
            onPositionChanged: function(mouse) {
                const next = root.width - mouse.x
                root.currentWidth = Math.max(
                    root.minWidth,
                    Math.min(root.maxWidth, next)
                )
            }
            onDoubleClicked: root.currentWidth = root.defaultWidth
        }
    }

    // Collapsed expand tab
    Rectangle {
        id: expandTab
        width: 34
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        visible: !root.open
        color: Theme.tokens.color.bgSidebar
        border.color: Theme.tokens.color.border
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: "AI 助手"
            font.pixelSize: 10
            rotation: 90
            color: Theme.tokens.color.textSecondary
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.currentWidth = root.defaultWidth
                root.open = true
            }
        }
    }
}
