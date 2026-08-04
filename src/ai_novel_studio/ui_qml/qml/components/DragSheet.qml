import QtQuick
import QtQuick.Layouts
import "../surfaces"

// DragSheet — 上下划动窗口的条（vertically draggable glass panel with a
// grabber handle）。用户要求“上下划动窗口的条”，即 iOS 底部 sheet / 控制
// 中心式的可上下拖动画板范本。
//
// Skill 驱动的关键行为（apple-design / emil-design-eng / animation-vocabulary，
// review-animations 自审见 glassmorphism-ui-log.md §18）：
// - 顶部 grabber 圆条 + header 整条是拖动区，面板 1:1 跟随指针（直接操作）；
// - 松手按“位置最近档 + 甩动速度”吸附到 collapsed(0) / preview(0.5) /
//   expanded(1) 三档（momentum projection 的简化版）；
// - 吸附用可打断 SpringAnimation，拖动中禁用保证跟手；
// - 拖过边界采用橡皮筋阻尼（rubber-banding），不硬停；
// - 只用 transform.translate 控制位移（GPU 友好，不触发布局）；
// - 玻璃面板用半透明底 + LiquidLights 边缘（不用实时 ShaderEffectSource：
//   transform 平移不会同步 ShaderEffectSource 捕获区，见 §18.1）；
// - reduceMotion 时吸附瞬间完成（保留功能、去掉运动）；Facade 缺失时兜底；
// - 档位/功能不依赖视觉，Safe/Balanced/Premium 均可拖动。
Item {
    id: root
    objectName: "dragSheet"

    property real collapsedHeight: 96
    property real previewHeight: 240
    property real expandedHeight: 380
    property real progress: 0.0
    property bool interactive: true
    property string title: ""
    signal closed()

    readonly property real travel: root.expandedHeight - root.collapsedHeight
    readonly property real collapsedY: root.travel
    // Readable handle for tests and external consumers (the Translate element
    // itself is not a child item, so it cannot be found by object name).
    readonly property real translateY: sheetTransform.y
    readonly property real springEnabled:
        // Note: never compare the Facade context property with `=== null` in
        // QML — context properties wrapped as QObject evaluate as null under
        // JS strict equality, which silently disables the spring. Use typeof
        // only (verified empirically; see §18.3).
        typeof Facade === "undefined" ? false : !Facade.reduceMotion
    // Theme token values are strings; assign through a typed `color` property
    // so .r/.g/.b resolve to numbers (same pitfall BackdropLayer documents:
    // Qt.rgba(undefined) silently produces black).
    readonly property color glassColor: Theme.tokens.color.bgSurface

    // Drag bookkeeping (pointer coordinates are in header-local space).
    property real dragStartY: 0
    property real dragStartProgress: 0
    property real lastMoveDelta: 0
    property bool updating: false

    onProgressChanged: {
        // Programmatic assignments (setProgress) clamp into 0..1; pointer drags
        // temporarily bypass so rubber-banding can overshoot.
        if (!root.updating) {
            root.updating = true
            root.progress = root.clampProgress(root.progress)
            root.updating = false
        }
    }

    implicitHeight: root.expandedHeight
    focus: root.visible
    Keys.onEscapePressed: root.closed()

    function clampProgress(p) {
        return Math.max(0.0, Math.min(1.0, p))
    }

    function setProgress(p) {
        root.updating = true
        root.progress = root.clampProgress(p)
        root.updating = false
    }

    // Pointer drag: upward (localY decreases) expands. Past either edge the
    // overshoot is damped in half (rubber-banding), then snaps back on release.
    function setFromPointer(localY) {
        var delta = localY - root.dragStartY
        var p = root.dragStartProgress - delta / root.travel
        if (p < 0) {
            p = p / 2
        }
        if (p > 1) {
            p = 1 + (p - 1) / 2
        }
        root.updating = true
        root.progress = p
        root.updating = false
    }

    // Snap decision: nearest tier + flick boost. velocity > 0 = fling down.
    function snapTarget(p, velocity) {
        var nearest = p < 0.25 ? 0.0 : (p < 0.75 ? 0.5 : 1.0)
        if (velocity > 120 && p > 0.25) {
            return p > 0.75 ? 0.5 : 0.0
        }
        if (velocity < -120 && p < 0.75) {
            return p < 0.25 ? 0.5 : 1.0
        }
        return nearest
    }

    function handleRelease() {
        root.setProgress(root.snapTarget(root.progress, root.lastMoveDelta))
    }

    // Glass body: bottom-anchored, moves up/down via transform.translate only.
    Rectangle {
        id: glass
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.expandedHeight
        radius: 16
        clip: true
        color: Qt.rgba(
            root.glassColor.r,
            root.glassColor.g,
            root.glassColor.b,
            Theme.visualQuality === "premium" ? 0.86 : 0.94
        )
        border.color: Theme.tokens.color.border
        border.width: 1

        transform: Translate {
            id: sheetTransform
            objectName: "dragSheetTransform"
            y: root.collapsedY * (1 - root.progress)
        }
        Behavior on y {
            enabled: root.springEnabled && !dragHeader.pressed
            SpringAnimation {
                spring: 2.4
                damping: 0.86
                epsilon: 0.02
            }
        }

        // Shared edge language with cards/panels (edge light + inner shadow).
        LiquidLights {
            objectName: "dragSheetLiquidLights"
            anchors.fill: parent
            radius: 16
            edgeLightOpacity: parseFloat(Theme.tokens.material.cardEdgeLight)
            innerShadowOpacity: parseFloat(Theme.tokens.material.cardInnerShadow)
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // --- Grabber + title row (drag zone). ---
            Item {
                id: header
                Layout.fillWidth: true
                Layout.preferredHeight: 48

                Rectangle {
                    id: grabber
                    objectName: "dragSheetGrabber"
                    width: 36
                    height: 4
                    radius: 2
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.tokens.color.textSecondary
                    opacity: root.interactive ? 1.0 : 0.45
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.topMargin: 16
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                        color: Theme.tokens.color.textPrimary
                    }
                    StatusChip {
                        label: "进度"
                        value: root.progress.toFixed(2)
                        tone: "accent"
                    }
                    AppButton {
                        objectName: "dragSheetCloseButton"
                        text: "关闭（Esc）"
                        ghost: true
                        onClicked: root.closed()
                    }
                }

                MouseArea {
                    id: dragHeader
                    anchors.fill: parent
                    enabled: root.interactive
                    cursorShape: root.interactive ? Qt.OpenHandCursor : Qt.ArrowCursor
                    onPressed: {
                        root.dragStartY = mouse.y
                        root.dragStartProgress = root.progress
                        root.lastMoveDelta = 0
                    }
                    onPositionChanged: {
                        root.setFromPointer(mouse.y)
                        root.lastMoveDelta = mouse.y - root.dragStartY
                    }
                    onReleased: root.handleRelease()
                }
            }

            // --- Content: how-to + tier dots + progress readout. ---
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 6
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text: "上下划动窗口的条 · DragSheet 范本"
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.tokens.color.textPrimary
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "抓住顶部圆条上下拖动：面板 1:1 跟随；松手按位置与甩动速度吸附到 收起 / 预览 / 展开 三档；拖过边界有橡皮筋阻尼；拖动中随时反向，弹簧可打断。"
                        font.pixelSize: 11
                        lineHeight: 1.6
                        wrapMode: Text.WordWrap
                        color: Theme.tokens.color.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: [
                                { label: "收起", value: 0 },
                                { label: "预览", value: 0.5 },
                                { label: "展开", value: 1 }
                            ]
                            delegate: Rectangle {
                                Layout.preferredWidth: 82
                                Layout.preferredHeight: 28
                                radius: 8
                                color: Math.abs(root.progress - modelData.value) < 0.001
                                    ? Theme.tokens.color.pressed
                                    : "transparent"
                                border.color: Theme.tokens.color.border
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    Rectangle {
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: Math.abs(root.progress - modelData.value) < 0.001
                                            ? Theme.tokens.color.accent
                                            : Theme.tokens.color.textSecondary
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        font.pixelSize: 10
                                        color: Theme.tokens.color.textPrimary
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Safe 实色面板 · Balanced 常规 · Premium 更透 + 弹簧吸附 · reduceMotion 下吸附瞬间完成"
                        font.pixelSize: 9
                        color: Theme.tokens.color.textSecondary
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }
}
