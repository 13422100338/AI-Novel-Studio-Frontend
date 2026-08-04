import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "design"
import "effects"
import "pages"
import "surfaces"

// Visual V0 sample page (ideal-UI spec 15, stage "Visual V0").
// Standalone by design: it is loaded through `--visual-lab` and never replaces
// the production shell. Every surface, button tier, Agent state, Diff/ChangeSet
// card, glow border and theme/quality switch is exercised here so the direction
// can be confirmed before any global replacement (spec: "由用户确认后再进入
// 全局替换").
ApplicationWindow {
    id: root
    objectName: "visualLabWindow"

    width: 1280
    height: 820
    minimumWidth: 1080
    minimumHeight: 700
    visible: true
    title: "AI Novel Studio · Visual V0 样板"
    color: Theme.tokens.color.bgCanvas
    font.family: Theme.tokens.font.ui

    // Staggered entrance for the three columns (occasional page, 50ms steps,
    // opacity only, respects reduceMotion).
    property int revealStep: 0
    Timer {
        interval: 50
        repeat: true
        running: root.visible
        onTriggered: {
            root.revealStep += 1
            if (root.revealStep >= 3) {
                stop()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Visual V0 · 理想 UI 样板"
                font.pixelSize: 18
                font.bold: true
                color: Theme.tokens.color.textPrimary
            }
            Text {
                text: "暖色纸张 + 冷色智能玻璃 · 所有表面均不实时模糊"
                font.pixelSize: 11
                color: Theme.tokens.color.textSecondary
            }
            Item {
                Layout.fillWidth: true
            }

            // 主题：三段式切换（paper / light / dark）
            RowLayout {
                spacing: 4
                Text {
                    text: "主题"
                    font.pixelSize: 11
                    color: Theme.tokens.color.textSecondary
                }
                Repeater {
                    model: ["paper", "light", "dark"]
                    AppButton {
                        objectName: "labTheme-" + modelData
                        text: modelData
                        selected: Theme.themeName === modelData
                        onClicked: Theme.setTheme(modelData)
                    }
                }
            }

            // 质量档：三段式切换（Safe / Balanced / Premium）
            RowLayout {
                spacing: 4
                Text {
                    text: "质量"
                    font.pixelSize: 11
                    color: Theme.tokens.color.textSecondary
                }
                Repeater {
                    model: ["safe", "balanced", "premium"]
                    AppButton {
                        objectName: "labQuality-" + modelData
                        text: modelData
                        primary: Theme.visualQuality === modelData
                        onClicked: Theme.setVisualQuality(modelData)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // --- Column 1: AI glass surface + agent states ---
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                opacity: root.revealStep >= 1 ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Facade.reduceMotion ? 0 : Theme.tokens.motion.normal
                        easing.type: Easing.OutCubic
                    }
                }

                GlassSurface {
                    id: agentGlass
                    objectName: "labGlassSurface"
                    anchors.fill: parent

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "AI 助手 · 玻璃表面"
                                font.pixelSize: 14
                                font.bold: true
                                color: Theme.tokens.color.textPrimary
                            }
                            StatusChip {
                                label: "生成中"
                                value: "2 个步骤"
                                tone: "accent"
                            }
                        }

                        // Currently active card wrapped in the streaming glow.
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 92

                            FlatSurface {
                                anchors.fill: parent
                                radius: Theme.tokens.radius.r12
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    color: "transparent"
                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 4
                                        Text {
                                            text: "正在生成修改稿"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: Theme.tokens.color.textPrimary
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "已读取当前章节与选区，正在按新要求重写第三段…"
                                            font.pixelSize: 10
                                            wrapMode: Text.WordWrap
                                            color: Theme.tokens.color.textSecondary
                                        }
                                    }
                                }
                            }
                            StreamingGlowBorder {
                                objectName: "labStreamingGlow"
                                anchors.fill: parent
                                radius: Theme.tokens.radius.r12
                                active: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "状态："
                                font.pixelSize: 10
                                color: Theme.tokens.color.textSecondary
                            }
                            StatusChip {
                                label: "思考"
                                value: "Thinking"
                                tone: "accent"
                            }
                            StatusChip {
                                label: "生成"
                                value: "Generating"
                                tone: "warning"
                            }
                            StatusChip {
                                label: "成功"
                                value: "Success"
                                tone: "success"
                            }
                            StatusChip {
                                label: "错误"
                                value: "Error"
                                tone: "danger"
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            AppButton {
                                text: "重写"
                                primary: true
                            }
                            AppButton {
                                text: "润色"
                            }
                            AppButton {
                                text: "再次生成"
                                ghost: true
                            }
                            AppButton {
                                text: "停止"
                                ghost: true
                            }
                        }

                        TextField {
                            objectName: "labInputField"
                            Layout.fillWidth: true
                            placeholderText: "向 AI 助手提问…（Enter 发送，Shift+Enter 换行）"
                            color: Theme.tokens.color.textPrimary
                            placeholderTextColor: Theme.tokens.color.textSecondary
                            font.pixelSize: 11
                            background: Rectangle {
                                radius: Theme.tokens.radius.r8
                                color: Theme.tokens.color.bgSurface
                                border.color: Theme.tokens.color.border
                                border.width: 1
                            }
                        }
                    }
                }
            }

            // --- Column 2: paper + button tiers ---
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                opacity: root.revealStep >= 2 ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Facade.reduceMotion ? 0 : Theme.tokens.motion.normal
                        easing.type: Easing.OutCubic
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    PaperSurface {
                        objectName: "labPaperSurface"
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 8

                            Text {
                                text: "正文纸张 · 第一章"
                                font.pixelSize: 15
                                font.bold: true
                                color: Theme.tokens.color.textPrimary
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "清晨的雾港还浸在灰蓝色的光线里。渡轮靠岸时，甲板上的水汽把远处灯塔的光晕揉成一团模糊的暖色。"
                                font.family: Theme.tokens.font.manuscript
                                font.pixelSize: 13
                                lineHeight: 1.8
                                wrapMode: Text.WordWrap
                                color: Theme.tokens.color.textPrimary
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "林默把最后一封信塞进外套内袋，沿着湿漉漉的栈桥走进镇子。"
                                font.family: Theme.tokens.font.manuscript
                                font.pixelSize: 13
                                lineHeight: 1.8
                                wrapMode: Text.WordWrap
                                color: Theme.tokens.color.textPrimary
                            }
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                            }
                            Text {
                                text: "约 640 字 · 已保存"
                                font.pixelSize: 10
                                color: Theme.tokens.color.textSecondary
                            }
                        }
                    }

                    ElevatedSurface {
                        objectName: "labElevatedSurface"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 148

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                text: "按钮层级"
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.tokens.color.textPrimary
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                AppButton {
                                    objectName: "labPrimaryButton"
                                    text: "主要操作"
                                    primary: true
                                }
                                AppButton {
                                    objectName: "labSecondaryButton"
                                    text: "次要操作"
                                }
                                AppButton {
                                    objectName: "labGhostButton"
                                    text: "轻量操作"
                                    ghost: true
                                }
                                AppButton {
                                    text: "已选中"
                                    selected: true
                                }
                                AppButton {
                                    text: "禁用"
                                    enabled: false
                                }
                            }
                            Text {
                                text: "Safe 档降级为不透明表面；Balanced/Premium 使用玻璃与噪声。"
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                color: Theme.tokens.color.textSecondary
                            }
                        }
                    }
                }
            }

            // --- Column 3: Agent cards with glow ---
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                opacity: root.revealStep >= 3 ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Facade.reduceMotion ? 0 : Theme.tokens.motion.normal
                        easing.type: Easing.OutCubic
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "Agent 结构化卡片"
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.tokens.color.textPrimary
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 116

                        TextDiffCard {
                            objectName: "labDiffCard"
                            anchors.fill: parent
                            label: "修改对比 · 第三段"
                            currentText: "渡轮靠岸时，甲板上的水汽把远处灯塔的光晕揉成一团模糊的暖色。"
                            draftText: "渡轮靠岸时，咸湿的水汽在甲板上流动，把远处灯塔的光晕揉成一团暖色。"
                            state: "PENDING"
                        }
                        StaticGlowBorder {
                            objectName: "labStaticGlow"
                            anchors.fill: parent
                            radius: Theme.tokens.radius.r12
                            tone: "generating"
                        }
                    }

                    ChangeSetCard {
                        objectName: "labChangeSetCard"
                        Layout.fillWidth: true
                        label: "变更提案"
                        target: "人物 · 林默"
                        operation: "更新"
                        beforeText: "码头工人"
                        afterText: "退役水手"
                        risk: "低"
                        reason: "Mock 提案：人物设定与第一章背景冲突"
                        state: "PENDING"
                    }

                    FormCard {
                        objectName: "labFormCard"
                        Layout.fillWidth: true
                        title: "补充设定"
                        description: "请补充人物关系设定（Mock 表单，不写入项目）"
                        fieldLabels: ["人物名", "关系", "备注"]
                        fieldValues: ["林默", "旧友", "待确认"]
                        state: "PENDING"
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "说明：本页为独立样板（--visual-lab），不替换正式界面。质量档 Safe/Balanced/Premium 与 reduceMotion 均会实时生效。"
            font.pixelSize: 10
            color: Theme.tokens.color.textSecondary
        }
    }
}
