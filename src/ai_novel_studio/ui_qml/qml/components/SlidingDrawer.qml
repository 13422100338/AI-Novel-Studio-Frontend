import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// TextArea-mode floating AI reference drawer. Content is the same
// CreativeAgentPanel used by AgentDock in WebEngine mode (C1.1 unification);
// the legacy DiscussionPanel is no longer the default rendering path.
Item {
    id: root
    z: 100

    property bool open: false
    property int drawerWidth: 340
    signal closed()

    anchors.fill: parent

    Rectangle {
        id: dim
        anchors.fill: parent
        color: "#80000000"
        opacity: root.open ? 1 : 0
        visible: root.open

        Behavior on opacity {
            NumberAnimation { duration: Facade.reduceMotion ? 0 : Theme.tokens.duration.fast }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    Rectangle {
        id: panel
        objectName: "aiDrawer"
        width: root.drawerWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        x: root.open ? 0 : root.drawerWidth
        color: Theme.tokens.color.bgSurface
        border.color: Theme.tokens.color.border
        border.width: 1
        clip: true

        Behavior on x {
            NumberAnimation { duration: Facade.reduceMotion ? 0 : Theme.tokens.duration.panel }
        }

        CreativeAgentPanel {
            anchors.fill: parent
        }

        AppButton {
            objectName: "drawerCloseButton"
            text: "关闭"
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            z: 2
            onClicked: root.closed()
        }
    }
}
