import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    objectName: "textDiffCard"

    property string itemId: ""
    property string state: ""
    property string label: ""
    property string currentText: ""
    property string draftText: ""
    signal approve()
    signal retry()
    signal discard()

    readonly property bool settled:
        state === "APPLIED" || state === "DISCARDED" || state === "CANCELLED"

    width: parent ? parent.width : 320
    implicitHeight: Math.max(40, column.implicitHeight + 12)
    radius: Theme.tokens.radius.r12
    color: Theme.tokens.color.bgSidebar
    border.color: Theme.tokens.color.border
    border.width: 1

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        Text {
            text: root.label
            font.pixelSize: 11
            font.bold: true
            color: Theme.tokens.color.textPrimary
        }
        Text {
            Layout.fillWidth: true
            text: "当前：" + root.currentText
            font.pixelSize: 11
            color: Theme.tokens.color.textSecondary
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            text: "修改：" + root.draftText
            font.pixelSize: 11
            color: Theme.tokens.color.warning
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Item { Layout.fillWidth: true }
            AppButton {
                text: "放弃"
                enabled: !root.settled
                onClicked: root.discard()
            }
            AppButton {
                text: "再次修改"
                enabled: !root.settled
                onClicked: root.retry()
            }
            AppButton {
                text: "确认替换"
                primary: true
                enabled: !root.settled
                onClicked: root.approve()
            }
        }
    }
}
