import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Codex-style Agent panel: structured timeline + composer (Frontend Wave C1).
// Card types are rendered through a component map; no giant delegate.
Item {
    id: root

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
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.tokens.color.border
        }

        ListView {
            id: timeline
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: Facade.agentTimeline
            ScrollBar.vertical: ScrollBar {}

            delegate: Loader {
                width: timeline.width
                sourceComponent: root.componentFor(kind)

                onLoaded: {
                    const item = item
                    if (item === null) {
                        return
                    }
                    if (kind === "user_text" || kind === "assistant_text") {
                        item.text = text
                        item.user = kind === "user_text"
                    } else if (kind === "run_status") {
                        item.label = label
                        item.busy = busy
                        item.status = status
                    } else if (kind === "tool_call" || kind === "tool_result") {
                        item.label = label
                        item.text = text
                    } else if (kind === "choice_card") {
                        item.options = options
                        item.chosen.connect(function(choice) {
                            Facade.agentReplyChoice(choice)
                        })
                    } else if (kind === "text_diff") {
                        item.label = label
                        item.currentText = currentText
                        item.draftText = draftText
                        item.approve.connect(Facade.approveAgentChangeSet)
                        item.discard.connect(Facade.discardAgentChangeSet)
                    } else if (kind === "confirmation") {
                        item.label = label
                        item.text = text
                        item.confirm.connect(Facade.approveAgentChangeSet)
                    } else if (kind === "warning" || kind === "error") {
                        item.text = text
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
        id: warningComponent
        AgentTextBlock {
            textColor: Theme.tokens.color.danger
        }
    }
}
