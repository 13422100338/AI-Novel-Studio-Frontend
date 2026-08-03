import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    objectName: "agentComposer"

    signal sendRequested(string text)
    signal stopRequested()
    signal quickCommand(string command)

    ContextReferenceChip {
        objectName: "selectionReferenceChip"
        visible: Facade.hasSelectionReference
        label: Facade.selectionReferenceLabel
        preview: Facade.selectionReferencePreview
        onCleared: Facade.clearSelectionReference()
    }

    Flow {
        Layout.fillWidth: true
        spacing: 4

        AppButton { text: "重写"; onClicked: root.quickCommand("重写") }
        AppButton { text: "润色"; onClicked: root.quickCommand("润色") }
        AppButton { text: "精简"; onClicked: root.quickCommand("精简") }
        AppButton { text: "扩写"; onClicked: root.quickCommand("扩写") }
        AppButton { text: "生成草稿"; onClicked: root.quickCommand("生成草稿") }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 76
        color: Theme.tokens.color.bgSurface
        border.color: Theme.tokens.color.border
        border.width: 1
        radius: Theme.tokens.radius.r8

        TextArea {
            id: input
            anchors.fill: parent
            anchors.margins: 6
            placeholderText: "向 AI 助手提问…（Enter 发送，Shift+Enter 换行）"
            placeholderTextColor: Theme.tokens.color.textSecondary
            color: Theme.tokens.color.textPrimary
            wrapMode: TextEdit.Wrap
            background: null

            Keys.onReturnPressed: {
                if (event.modifiers & Qt.ShiftModifier) {
                    input.insert(input.cursorPosition, "\n")
                    event.accepted = true
                } else {
                    root.submit()
                    event.accepted = true
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Item { Layout.fillWidth: true }

        AppButton {
            objectName: "agentStopButton"
            text: "停止"
            visible: Facade.agentBusy
            onClicked: root.stopRequested()
        }
        AppButton {
            objectName: "agentSendButton"
            text: "发送"
            primary: true
            enabled: input.text.trim() !== "" && !Facade.agentBusy
            onClicked: root.submit()
        }
    }

    function submit() {
        const text = input.text
        if (text.trim() === "" || Facade.agentBusy) {
            return
        }
        input.text = ""
        root.sendRequested(text)
    }
}
