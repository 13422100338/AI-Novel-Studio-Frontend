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
    // Set by the launcher (bootstrap.py) when the Windows 11 DWM system
    // backdrop (Mica) was applied: the window turns transparent so the
    // wallpaper blur behind the window shows through the lab backdrop.
    property bool systemBackdrop: false
    // Mica is active only for Balanced/Premium; Safe keeps a fully opaque
    // window so the wallpaper never shows through (spec 11: Safe = 实色背景).
    readonly property bool micaActive:
        root.systemBackdrop && Theme.visualQuality !== "safe"
    // Premium uses Desktop Acrylic (brighter); let slightly more wallpaper
    // through than Balanced so the quality tiers read differently.
    // Keep the wash light: a heavy wash (0.8) was observed to hide the DWM
    // backdrop entirely, leaving a flat gray pane (verified on a real Win11
    // machine: DwmSetWindowAttribute returns S_OK and the window is not
    // layered, so the gray was our own wash, not a failed API call).
    readonly property real backdropWashAlpha:
        Theme.visualQuality === "premium" ? 0.18 : 0.32
    color: root.micaActive ? "transparent" : Theme.tokens.color.bgCanvas
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

    // Resize repaint guard: Qt Quick can leave newly exposed areas unpainted
    // after a window resize on some Windows GPU/driver combinations (seen as
    // black L-shaped bands at the right/bottom edges). Forcing a scene-graph
    // update after the resize settles repaints those areas.
    Timer {
        id: resizeRepaintTimer
        interval: 60
        repeat: false
        onTriggered: {
            if (root.visible) {
                root.update()
            }
        }
    }
    onWidthChanged: resizeRepaintTimer.restart()
    onHeightChanged: resizeRepaintTimer.restart()

    // ---------------------------------------------------------------------
    // App-controlled backdrop (glass course correction, recommended route):
    // opaque window + in-app BackdropLayer + Acrylic panels above. The
    // system Mica backdrop remains an optional experiment only.
    // ---------------------------------------------------------------------
    BackdropLayer {
        id: backgroundLayer
        objectName: "labBackgroundLayer"
        anchors.fill: parent
        washEnabled: root.micaActive
        washAlpha: root.backdropWashAlpha
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
                text: "暖色纸张 + 冷色智能玻璃 · 主路线：应用内 Acrylic（推荐）；系统 Mica 仅作可选实验（正式界面未改动）"
                font.pixelSize: 11
                color: Theme.tokens.color.textSecondary
            }
            // Optional-experiment marker: live confirmation of the DWM system
            // backdrop; hidden on the offscreen path where Mica cannot render.
            StatusChip {
                objectName: "labBackdropStatusChip"
                visible: root.systemBackdrop
                label: "Mica 实验"
                value: Theme.visualQuality === "safe"
                    ? "Safe 关闭"
                    : Theme.visualQuality === "premium" ? "Desktop Acrylic" : "Mica"
                tone: "warning"
            }
            Item {
                Layout.fillWidth: true
            }

            AppButton {
                objectName: "labReduceMotionButton"
                text: Facade.reduceMotion ? "动效：关" : "动效：开"
                ghost: true
                onClicked: Facade.setReduceMotion(!Facade.reduceMotion)
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

                // AI pane: two material modes sharing one content column.
                // - Default: real-time Acrylic capturing the in-app backdrop
                //   layer (experimental comparison).
                // - systemBackdrop (Mica): opaque glass that never lets the
                //   wallpaper through, keeping the glass decorations only.
                Item {
                    anchors.fill: parent

                    AcrylicSurface {
                        id: agentAcrylic
                        objectName: "labAcrylicSurface"
                        anchors.fill: parent
                        sourceItem: backgroundLayer
                        visible: !root.micaActive
                    }

                    GlassSurface {
                        id: agentGlass
                        objectName: "labGlassSurface"
                        anchors.fill: parent
                        opaque: true
                        visible: root.micaActive
                    }

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
                                id: streamingGlow
                                objectName: "labStreamingGlow"
                                anchors.fill: parent
                                radius: Theme.tokens.radius.r12
                                active: true
                            }
                        }

                        // 流光状态演示（规范 8.1）：成功/错误/取消定格状态色，
                        // 运行态 A↔B 慢速漂移；reduceMotion 退化为静态高亮。
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "流光状态："
                                font.pixelSize: 10
                                color: Theme.tokens.color.textSecondary
                            }
                            AppButton {
                                objectName: "labGlowThinking"
                                text: "Thinking"
                                ghost: true
                                onClicked: streamingGlow.state = ""
                            }
                            AppButton {
                                objectName: "labGlowSuccess"
                                text: "Success"
                                ghost: true
                                onClicked: streamingGlow.state = "success"
                            }
                            AppButton {
                                objectName: "labGlowError"
                                text: "Error"
                                ghost: true
                                onClicked: streamingGlow.state = "error"
                            }
                            AppButton {
                                objectName: "labGlowCancelled"
                                text: "Cancelled"
                                ghost: true
                                onClicked: streamingGlow.state = "cancelled"
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
                        Layout.preferredHeight: 172

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
                                text: "Safe 档降级为不透明表面；Balanced/Premium 启用实时 Acrylic 背景模糊（仅实验页）。"
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                color: Theme.tokens.color.textSecondary
                            }

                            // 材质层次对比：模拟玻璃 vs 实时 Acrylic vs 实色（规范 4.2）。
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                spacing: 8

                                GlassSurface {
                                    objectName: "labGlassCompare"
                                    Layout.preferredWidth: 150
                                    Layout.fillHeight: true
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        Text {
                                            text: "玻璃（模拟）"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: Theme.tokens.color.textPrimary
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "AI / 壳层 · 流动"
                                            font.pixelSize: 9
                                            wrapMode: Text.WordWrap
                                            color: Theme.tokens.color.textSecondary
                                        }
                                    }
                                }
                                AcrylicSurface {
                                    objectName: "labAcrylicCompare"
                                    visible: !root.micaActive
                                    Layout.preferredWidth: 150
                                    Layout.fillHeight: true
                                    sourceItem: backgroundLayer
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        Text {
                                            text: "Acrylic（实时）"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: Theme.tokens.color.textPrimary
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "背景模糊 · 实验评估"
                                            font.pixelSize: 9
                                            wrapMode: Text.WordWrap
                                            color: Theme.tokens.color.textSecondary
                                        }
                                    }
                                }
                                // Mica mode: the wallpaper shows through the
                                // window backdrop only; panels stay opaque.
                                Rectangle {
                                    objectName: "labMicaCompare"
                                    visible: root.micaActive
                                    Layout.preferredWidth: 150
                                    Layout.fillHeight: true
                                    radius: Theme.tokens.radius.r12
                                    color: "transparent"
                                    border.color: Theme.tokens.color.border
                                    border.width: 1
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        Text {
                                            text: "Mica 底板"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: Theme.tokens.color.textPrimary
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "壁纸透出 · 面板不透"
                                            font.pixelSize: 9
                                            wrapMode: Text.WordWrap
                                            color: Theme.tokens.color.textSecondary
                                        }
                                    }
                                }
                                FlatSurface {
                                    objectName: "labFlatCompare"
                                    Layout.preferredWidth: 150
                                    Layout.fillHeight: true
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        Text {
                                            text: "实色"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: Theme.tokens.color.textPrimary
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "基础表面 · 稳定"
                                            font.pixelSize: 9
                                            wrapMode: Text.WordWrap
                                            color: Theme.tokens.color.textSecondary
                                        }
                                    }
                                }
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
            text: "说明：本页为独立样板（--visual-lab），不替换正式界面。质量档 Safe 关闭实时模糊（实色表面），Balanced/Premium 启用实时 Acrylic 背景模糊，均仅在本实验页生效；reduceMotion 实时生效。"
            font.pixelSize: 10
            color: Theme.tokens.color.textSecondary
        }
    }
}
