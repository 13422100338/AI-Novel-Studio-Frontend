import QtQuick
import QtQuick.Layouts
import "../surfaces"

// SliderTemplateDock — showcase for the GlassSlider template in Visual V0.
// The dock folds up from the bottom of the lab (same pattern as the top
// ExperimentControlPanel) so it never covers the workspace; Escape closes it.
//
// Entrance: the four sample columns stagger in (40ms gaps, fade + 6px rise,
// emil-design-eng stagger guidance) and are skipped entirely when
// reduceMotion is on (apple-design §14). The dock is a utility strip, so it
// closes instantly — no exit animation (emil: never animate keyboard/utility
// actions users hit often).
Item {
    id: root
    objectName: "sliderTemplateDock"

    signal closed()
    focus: root.visible
    Keys.onEscapePressed: root.closed()

    implicitHeight: body.implicitHeight + 24

    onVisibleChanged: {
        if (!root.visible) {
            return
        }
        var reduceMotion =
            typeof Facade !== "undefined" && Facade !== null && Facade.reduceMotion
        if (reduceMotion) {
            col1.opacity = col2.opacity = col3.opacity = col4.opacity = 1
            t1.y = t2.y = t3.y = t4.y = 0
            return
        }
        col1.opacity = col2.opacity = col3.opacity = col4.opacity = 0
        t1.y = t2.y = t3.y = t4.y = 6
        stagger.restart()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.tokens.color.bgSurface
        border.color: Theme.tokens.color.border
        border.width: 1
        radius: Theme.tokens.radius.r12

        // Same edge language as cards/panels (edge light + inner shadow).
        LiquidLights {
            objectName: "sliderDockLiquidLights"
            anchors.fill: parent
            radius: Theme.tokens.radius.r12
            edgeLightOpacity: parseFloat(Theme.tokens.material.cardEdgeLight)
            innerShadowOpacity: parseFloat(Theme.tokens.material.cardInnerShadow)
        }
    }

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "滑动条范本 · GlassSlider"
                font.pixelSize: 13
                font.bold: true
                color: Theme.tokens.color.textPrimary
            }
            Text {
                text: "Safe 实色 / Balanced 常规 / Premium 渐变 + 弹簧"
                font.pixelSize: 10
                color: Theme.tokens.color.textSecondary
            }
            AppButton {
                objectName: "sliderTemplateCloseButton"
                text: "关闭（Esc）"
                ghost: true
                onClicked: root.closed()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            ColumnLayout {
                id: col1
                Layout.fillWidth: true
                spacing: 4
                opacity: 0
                transform: Translate { id: t1; y: 6 }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                GlassSlider {
                    objectName: "glassSliderPrimary"
                    Layout.fillWidth: true
                    title: "生成强度"
                    unit: "%"
                    from: 0
                    to: 100
                    value: 42
                    accent: Theme.tokens.agent.thinkingA
                }
                Text {
                    text: "拖动 · 实时气泡 · 弹簧回弹"
                    font.pixelSize: 9
                    color: Theme.tokens.color.textSecondary
                }
            }

            ColumnLayout {
                id: col2
                Layout.fillWidth: true
                spacing: 4
                opacity: 0
                transform: Translate { id: t2; y: 6 }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                GlassSlider {
                    objectName: "glassSliderSteps"
                    Layout.fillWidth: true
                    title: "章节字数目标"
                    unit: " 字"
                    from: 800
                    to: 4000
                    stepSize: 100
                    value: 2100
                    showValue: true
                }
                Text {
                    text: "步进 100 · 常显数值"
                    font.pixelSize: 9
                    color: Theme.tokens.color.textSecondary
                }
            }

            ColumnLayout {
                id: col3
                Layout.fillWidth: true
                spacing: 4
                opacity: 0
                transform: Translate { id: t3; y: 6 }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                GlassSlider {
                    objectName: "glassSliderDisabled"
                    Layout.fillWidth: true
                    title: "面板透明度"
                    unit: "%"
                    from: 0
                    to: 100
                    value: 60
                    interactive: false
                    showValue: true
                }
                Text {
                    text: "禁用态 · 不可拖动"
                    font.pixelSize: 9
                    color: Theme.tokens.color.textSecondary
                }
            }

            ColumnLayout {
                id: col4
                Layout.fillWidth: true
                spacing: 4
                opacity: 0
                transform: Translate { id: t4; y: 6 }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                GlassSlider {
                    objectName: "glassSliderAccent"
                    Layout.fillWidth: true
                    title: "氛围温度"
                    unit: "°C"
                    from: -20
                    to: 40
                    value: 12
                    showValue: true
                    accent: Theme.tokens.color.warning
                }
                Text {
                    text: "自定义 accent · 负区间"
                    font.pixelSize: 9
                    color: Theme.tokens.color.textSecondary
                }
            }
        }
    }

    SequentialAnimation {
        id: stagger
        ScriptAction {
            script: {
                col1.opacity = 1
                t1.y = 0
            }
        }
        PauseAnimation { duration: 40 }
        ScriptAction {
            script: {
                col2.opacity = 1
                t2.y = 0
            }
        }
        PauseAnimation { duration: 40 }
        ScriptAction {
            script: {
                col3.opacity = 1
                t3.y = 0
            }
        }
        PauseAnimation { duration: 40 }
        ScriptAction {
            script: {
                col4.opacity = 1
                t4.y = 0
            }
        }
    }
}
