import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    objectName: "confirmationCard"

    property string itemId: ""
    property string state: ""
    property string label: ""
    property string text: ""
    signal confirm()
    signal cancel()

    readonly property bool settled:
        state === "APPLIED" || state === "DISCARDED" || state === "CANCELLED"

    width: parent ? parent.width : 320
    implicitHeight: Math.max(30, row.implicitHeight + 12)
    radius: Theme.tokens.radius.r12
    color: Theme.tokens.color.bgSurface
    border.color: Theme.tokens.color.border
    border.width: 1

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: root.label
                font.pixelSize: 11
                font.bold: true
                color: Theme.tokens.color.textPrimary
            }
            Text {
                text: root.text
                font.pixelSize: 11
                color: Theme.tokens.color.textSecondary
            }
        }
        AppButton {
            text: "取消"
            enabled: !root.settled
            onClicked: root.cancel()
        }
        AppButton {
            text: "确认"
            primary: true
            enabled: !root.settled
            onClicked: root.confirm()
        }
    }
}
