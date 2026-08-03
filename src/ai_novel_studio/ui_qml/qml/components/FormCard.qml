import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Mock form card (C1.1): 1-3 fixed fields, save/skip/cancel, itemId-routed.
// No dynamic form engine and no real persistence in C1.
Rectangle {
    id: root
    objectName: "formCard"

    property string itemId: ""
    property string title: ""
    property string description: ""
    property var fieldLabels: []
    property var fieldValues: []
    property string state: ""
    signal submitted(string itemId, string valuesJson)
    signal skipped(string itemId)
    signal cancelled(string itemId)

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
            text: root.title
            font.pixelSize: 11
            font.bold: true
            color: Theme.tokens.color.textPrimary
        }
        Text {
            Layout.fillWidth: true
            visible: root.description !== ""
            text: root.description
            font.pixelSize: 11
            color: Theme.tokens.color.textSecondary
            wrapMode: Text.WordWrap
        }

        Repeater {
            id: fieldRepeater
            Layout.fillWidth: true
            model: root.fieldLabels.length
            delegate: TextField {
                Layout.fillWidth: true
                objectName: "formFieldInput"
                text: root.fieldValues.length > index ? root.fieldValues[index] : ""
                placeholderText: root.fieldLabels[index] || ("字段 " + (index + 1))
                enabled: !root.settled
                color: Theme.tokens.color.textPrimary
                placeholderTextColor: Theme.tokens.color.textSecondary
                background: Rectangle {
                    radius: Theme.tokens.radius.r8
                    color: Theme.tokens.color.bgSurface
                    border.color: Theme.tokens.color.border
                    border.width: 1
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Item {
                Layout.fillWidth: true
            }
            AppButton {
                text: "取消"
                enabled: !root.settled
                onClicked: root.cancelled(root.itemId)
            }
            AppButton {
                text: "跳过"
                enabled: !root.settled
                onClicked: root.skipped(root.itemId)
            }
            AppButton {
                text: "保存"
                primary: true
                enabled: !root.settled
                onClicked: root.submitted(root.itemId, root.collectValues())
            }
        }
    }

    function collectValues() {
        var values = []
        for (var i = 0; i < fieldRepeater.count; i++) {
            values.push(fieldRepeater.itemAt(i).text)
        }
        return JSON.stringify(values)
    }
}
