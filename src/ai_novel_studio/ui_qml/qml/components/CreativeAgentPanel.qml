import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Codex-style Agent panel: structured timeline + composer (Frontend Wave C1).
// Card types are rendered through a component map; no giant delegate.
Item {
    id: root
    objectName: "creativeAgentPanel"

    // Shared responsive layout rules (C1.2):
    // delegate width = timeline width - vertical scrollbar - safety margin.
    // Every timeline card fills this width; nothing may use a fixed width.
    property int scrollbarWidth: 10
    property int contentSafeMargin: 12
    // Test/diagnostic hook: lets a harness force delegate instantiation for
    // layout assertions without scrolling. No effect in normal use.
    property int timelineCacheBuffer: 0
    // Before/after diagnostic hook: emulates the pre-C1.2 delegate width rule
    // (cards run under the scrollbar). Normal use keeps this false.
    property bool timelineDelegateFullWidth: false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: "AI 助手"
                font.pixelSize: 15
                font.bold: true
                color: Theme.tokens.color.textPrimary
            }
            Text {
                text: Facade.agentBusy ? "忙碌" : "就绪"
                font.pixelSize: 10
                color: Facade.agentBusy
                    ? Theme.tokens.color.accent
                    : Theme.tokens.color.success
            }
            AppButton {
                objectName: "agentCloseButton"
                text: "×"
                implicitWidth: 28
                implicitHeight: 24
                onClicked: Facade.toggleAiDrawer(false)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.tokens.color.border
        }

        ListView {
            id: timeline
            objectName: "agentTimeline"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cacheBuffer: root.timelineCacheBuffer
            spacing: 8
            model: Facade.agentTimeline
            ScrollBar.vertical: ScrollBar {
                width: root.scrollbarWidth
                policy: ScrollBar.AsNeeded
            }

            delegate: Loader {
                id: delegateLoader
                // Content width of the list viewport: never let a card extend
                // under the scrollbar or past the visible area.
                width: Math.max(
                    0,
                    root.timelineDelegateFullWidth
                        ? timeline.width
                        : timeline.width - root.scrollbarWidth - root.contentSafeMargin
                )
                sourceComponent: root.componentFor(kind)

                onLoaded: {
                    const loadedItem = delegateLoader.item
                    if (loadedItem === null) {
                        return
                    }
                    if (kind === "user_text" || kind === "assistant_text") {
                        loadedItem.text = text
                        loadedItem.user = kind === "user_text"
                    } else if (kind === "run_status") {
                        loadedItem.label = label
                        loadedItem.busy = busy
                        loadedItem.status = status
                    } else if (kind === "tool_call" || kind === "tool_result") {
                        loadedItem.label = label
                        loadedItem.text = text
                    } else if (kind === "choice_card") {
                        loadedItem.options = options
                        loadedItem.chosen.connect(function(choice) {
                            Facade.agentReplyChoice(choice)
                        })
                    } else if (kind === "text_diff") {
                        loadedItem.itemId = itemId
                        loadedItem.state = state
                        loadedItem.label = label
                        loadedItem.currentText = currentText
                        loadedItem.draftText = draftText
                        loadedItem.approve.connect(function() {
                            Facade.approveAgentItem(itemId)
                        })
                        loadedItem.retry.connect(function() {
                            Facade.retryAgentItem(itemId)
                        })
                        loadedItem.discard.connect(function() {
                            Facade.discardAgentItem(itemId)
                        })
                    } else if (kind === "confirmation") {
                        loadedItem.itemId = itemId
                        loadedItem.state = state
                        loadedItem.label = label
                        loadedItem.text = text
                        loadedItem.confirm.connect(function() {
                            Facade.approveAgentItem(itemId)
                        })
                        loadedItem.cancel.connect(function() {
                            Facade.cancelAgentItem(itemId)
                        })
                    } else if (kind === "form_card") {
                        loadedItem.itemId = itemId
                        loadedItem.state = state
                        loadedItem.title = label
                        loadedItem.description = text
                        loadedItem.fieldLabels = fieldLabels
                        loadedItem.fieldValues = fieldValues
                        loadedItem.submitted.connect(function(valuesJson) {
                            Facade.submitAgentForm(itemId, valuesJson)
                        })
                        loadedItem.skipped.connect(function() {
                            Facade.skipAgentForm(itemId)
                        })
                        loadedItem.cancelled.connect(function() {
                            Facade.cancelAgentItem(itemId)
                        })
                    } else if (kind === "change_set") {
                        loadedItem.itemId = itemId
                        loadedItem.state = state
                        loadedItem.label = label
                        loadedItem.target = target
                        loadedItem.operation = operation
                        loadedItem.beforeText = beforeText
                        loadedItem.afterText = afterText
                        loadedItem.risk = risk
                        loadedItem.reason = reason
                        loadedItem.approve.connect(function() {
                            Facade.approveAgentItem(itemId)
                        })
                        loadedItem.edit.connect(function() {
                            Facade.editAgentChangeSet(itemId)
                        })
                        loadedItem.discard.connect(function() {
                            Facade.discardAgentItem(itemId)
                        })
                    } else if (kind === "warning" || kind === "error") {
                        loadedItem.text = text
                    }
                }
            }

            EmptyState {
                anchors.fill: parent
                visible: Facade.agentTimeline.count === 0
                title: "AI 助手"
                body: "就当前章节、正文选区或创作问题与 AI 商讨；回复为 Mock，后端 Agent 接入后启用真实操作。"
            }
        }

        AgentComposer {
            Layout.fillWidth: true
            onSendRequested: function(text) {
                Facade.startAgentTurn(text)
            }
            onStopRequested: Facade.stopAgentTurn()
            onQuickCommand: function(command) {
                if (command === "生成草稿") {
                    Facade.requestDraft()
                    Facade.startAgentTurn("生成章节草稿")
                } else {
                    Facade.startAgentTurn(command)
                }
            }
        }
    }

    function componentFor(kind) {
        switch (kind) {
        case "user_text":
        case "assistant_text":
            return agentTextComponent
        case "run_status":
            return runStatusComponent
        case "tool_call":
        case "tool_result":
            return toolCallComponent
        case "choice_card":
            return choiceCardComponent
        case "text_diff":
            return textDiffComponent
        case "confirmation":
            return confirmationComponent
        case "form_card":
            return formCardComponent
        case "change_set":
            return changeSetComponent
        case "warning":
        case "error":
            return warningComponent
        default:
            return undefined
        }
    }

    Component {
        id: agentTextComponent
        AgentTextBlock {}
    }
    Component {
        id: runStatusComponent
        AgentRunStatus {}
    }
    Component {
        id: toolCallComponent
        ToolCallCard {}
    }
    Component {
        id: choiceCardComponent
        ChoiceCard {}
    }
    Component {
        id: textDiffComponent
        TextDiffCard {}
    }
    Component {
        id: confirmationComponent
        ConfirmationCard {}
    }
    Component {
        id: formCardComponent
        FormCard {}
    }
    Component {
        id: changeSetComponent
        ChangeSetCard {}
    }
    Component {
        id: warningComponent
        AgentTextBlock {
            textColor: Theme.tokens.color.danger
        }
    }
}
