import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Experiment controls for the Visual V0 rework (diagnosis doc §10).
// The main page only shows the title and an "实验控制" entry; everything
// technical (theme / quality / motion / debug overlays / Mica experiment)
// lives in this right-side drawer so the main view is for visual review.
Item {
    id: root
    objectName: "experimentControlPanel"

    property bool open: false
    property bool debugBackdrop: false
    property bool debugSourceRect: false
    property bool debugBlurRegion: false
    property bool micaExperiment: false
    property string micaStatus: "未启用"
    signal closed()

    function requestMica(enable: bool) {
        var ok = false
        if (enable) {
            ok = BackdropBridge.apply("mica")
        } else {
            BackdropBridge.apply("none")
        }
        root.micaStatus = enable
            ? (ok ? "Mica 已启用（真机确认）" : "不可用（本机不支持/离屏）")
            : "未启用"
        return ok
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.tokens.color.scrim
        opacity: root.open ? 1 : 0
        visible: root.open

        Behavior on opacity {
            NumberAnimation {
                duration: Facade.reduceMotion ? 0 : Theme.tokens.duration.fast
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    Rectangle {
        id: panel
        width: 320
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        color: Theme.tokens.color.bgSurface
        border.color: Theme.tokens.color.border
        border.width: 1
        clip: true
        x: root.open ? 0 : root.width

        Behavior on x {
            NumberAnimation {
                duration: Facade.reduceMotion ? 0 : Theme.tokens.duration.panel
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "实验控制"
                    font.pixelSize: 14
                    font.bold: true
                    color: Theme.tokens.color.textPrimary
                }
                AppButton {
                    objectName: "experimentCloseButton"
                    text: "关闭"
                    ghost: true
                    onClicked: root.closed()
                }
            }

            Text {
                text: "主题"
                font.pixelSize: 11
                font.bold: true
                color: Theme.tokens.color.textSecondary
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
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

            Text {
                text: "质量"
                font.pixelSize: 11
                font.bold: true
                color: Theme.tokens.color.textSecondary
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
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

            Text {
                text: "动效"
                font.pixelSize: 11
                font.bold: true
                color: Theme.tokens.color.textSecondary
            }
            AppButton {
                objectName: "labReduceMotionButton"
                Layout.fillWidth: true
                text: Facade.reduceMotion ? "动效：关（reduceMotion）" : "动效：开"
                ghost: true
                onClicked: Facade.setReduceMotion(!Facade.reduceMotion)
            }

            // Mica is an optional, default-off experiment (course correction).
            Text {
                text: "系统 Mica（实验）"
                font.pixelSize: 11
                font.bold: true
                color: Theme.tokens.color.textSecondary
            }
            AppButton {
                objectName: "labMicaToggle"
                Layout.fillWidth: true
                text: root.micaExperiment ? "Mica：开（点此关闭）" : "Mica：关（默认）"
                primary: root.micaExperiment
                onClicked: {
                    root.micaExperiment = !root.micaExperiment
                    root.requestMica(root.micaExperiment)
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.micaStatus
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                color: Theme.tokens.color.textSecondary
            }

            Text {
                text: "调试叠加"
                font.pixelSize: 11
                font.bold: true
                color: Theme.tokens.color.textSecondary
            }
            AppButton {
                objectName: "labDebugBackdropToggle"
                Layout.fillWidth: true
                text: root.debugBackdrop ? "背景原图：显示" : "背景原图：隐藏"
                ghost: true
                onClicked: root.debugBackdrop = !root.debugBackdrop
            }
            AppButton {
                objectName: "labDebugSourceRectToggle"
                Layout.fillWidth: true
                text: root.debugSourceRect ? "sourceRect：显示" : "sourceRect：隐藏"
                ghost: true
                onClicked: root.debugSourceRect = !root.debugSourceRect
            }
            AppButton {
                objectName: "labDebugBlurRegionToggle"
                Layout.fillWidth: true
                text: root.debugBlurRegion ? "blur 区域：显示" : "blur 区域：隐藏"
                ghost: true
                onClicked: root.debugBlurRegion = !root.debugBlurRegion
            }

            Item {
                Layout.fillHeight: true
            }

            Text {
                Layout.fillWidth: true
                text: "说明：本页为独立样板（--visual-lab），不替换正式界面；质量档共享同一布局，仅改变模糊/噪声/阴影强度。Mica 默认关闭。"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                color: Theme.tokens.color.textSecondary
            }
        }
    }
}
