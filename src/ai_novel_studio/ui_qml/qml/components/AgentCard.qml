import QtQuick
import QtQuick.Layouts

// Shared timeline card container (C1.2). Centralizes the responsive rules that
// every Agent timeline card must follow:
//   - the card fills the delegate width (which already excludes the vertical
//     scrollbar and a 12px safety margin);
//   - long text wraps instead of eliding or overflowing;
//   - action rows use Flow so buttons wrap when the panel is narrow.
// Do not add per-card fixed widths; adjust this container or the shared
// CreativeAgentPanel width rules instead.
Rectangle {
    id: root

    // Declared on the root so consumers can put child items directly inside.
    default property alias content: contentColumn.data

    Layout.fillWidth: true
    implicitWidth: parent ? parent.width : 320
    radius: Theme.tokens.radius.r12
    color: Theme.tokens.color.bgSidebar
    border.color: Theme.tokens.color.border
    border.width: 1

    property string cardTitle: ""
    property color titleColor: Theme.tokens.color.textPrimary

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        Text {
            Layout.fillWidth: true
            visible: root.cardTitle !== ""
            text: root.cardTitle
            font.pixelSize: 11
            font.bold: true
            wrapMode: Text.WordWrap
            color: root.titleColor
        }

        ColumnLayout {
            id: contentColumn
            Layout.fillWidth: true
            spacing: 6
        }
    }
}
