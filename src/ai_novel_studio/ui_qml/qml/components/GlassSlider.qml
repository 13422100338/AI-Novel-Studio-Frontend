import QtQuick
import QtQuick.Layouts
import "../surfaces"

// GlassSlider — the Visual V0 slider template (frontend-design / emil-design-eng
// / apple-design / animation-vocabulary driven; self-reviewed with
// review-animations, see glassmorphism-ui-log.md §17).
//
// Design decisions:
// - Feedback fires on pointer-down and tracks 1:1 while dragging (apple-design
//   "response / direct manipulation"); the thumb never waits for release.
// - The thumb snaps to the pointer x; value changes are clamped + stepped so
//   data stays valid in every visual tier (glass-UI doc §12.3: functionality
//   must not depend on visuals).
// - Motion stays on transform/opacity only: thumb x/scale use Behaviors
//   (interruptible, GPU-friendly), the value bubble fades/scale-ins from
//   0.95 (emil-design-eng: never scale(0)), press scales the thumb via the
//   same binding that springs back on release (spring, damping 0.7 — tiny
//   bounce only because a drag release carries momentum, apple-design §4).
// - Facade.reduceMotion disables springs/behaviors (apple-design §14);
//   Safe tier drops the glass rim and gradient (still fully functional).
Item {
    id: root
    objectName: "glassSlider"

    implicitWidth: 240
    implicitHeight: 84

    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 0
    property string title: ""
    property string unit: ""
    property bool showValue: false
    property bool bubbleOnDrag: true
    property bool interactive: true
    property color accent: Theme.tokens.color.accent

    readonly property bool dragging: dragArea.pressed
    // Guarded so the lab keeps working even if the Facade context property is
    // unavailable during early binding (same pattern as AppButton).
    readonly property bool springEnabled:
        typeof Facade === "undefined" || Facade === null ? true : !Facade.reduceMotion
    readonly property real trackLeft: track.x
    readonly property real trackWidth: track.width
    readonly property real thumbCenterX: thumb.x + thumb.width / 2
    readonly property real normalized:
        root.to !== root.from ? (root.value - root.from) / (root.to - root.from) : 0

    property bool updating: false
    onValueChanged: {
        // Property-level guard: any assignment clamps + snaps to step, so
        // programmatic and pointer input share one validation path.
        if (!root.updating) {
            root.updating = true
            root.value = root.clampValue(root.value)
            root.updating = false
        }
    }

    opacity: root.interactive ? 1.0 : 0.45

    function clampValue(v) {
        var min = Math.min(root.from, root.to)
        var max = Math.max(root.from, root.to)
        v = Math.max(min, Math.min(max, v))
        if (root.stepSize > 0) {
            v = Math.round(v / root.stepSize) * root.stepSize
            v = Math.max(min, Math.min(max, v))
        }
        return v
    }

    function setFromPointer(px) {
        var t = (px - root.trackLeft) / Math.max(1, root.trackWidth)
        t = Math.max(0, Math.min(1, t))
        root.value = root.clampValue(root.from + t * (root.to - root.from))
    }

    function formatValue() {
        var text = (Math.abs(root.to - root.from) >= 1 || root.stepSize > 0)
            ? root.value.toFixed(0)
            : root.value.toFixed(1)
        return text + root.unit
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: 10
                color: Theme.tokens.color.textSecondary
                elide: Text.ElideRight
            }
            Text {
                visible: root.showValue
                text: root.formatValue()
                font.pixelSize: 10
                font.family: Theme.tokens.font.mono
                color: root.accent
            }
        }

        Item {
            id: gestureArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Track: flat 4px bar (flat-style guardrail from §13).
            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Theme.tokens.color.border
            }

            // Fill: solid accent (safe/balanced) or accent gradient (premium).
            Rectangle {
                id: fill
                anchors.left: track.left
                anchors.verticalCenter: track.verticalCenter
                height: 4
                radius: 2
                width: Math.max(0, root.thumbCenterX - root.trackLeft)
                gradient: Theme.visualQuality === "premium" ? fillGradient : null
                color: Theme.visualQuality === "premium" ? "transparent" : root.accent
            }
            Gradient {
                id: fillGradient
                GradientStop {
                    position: 0.0
                    color: Qt.lighter(root.accent, 1.35)
                }
                GradientStop {
                    position: 1.0
                    color: root.accent
                }
            }

            // Thumb: press scales up instantly (feedback on pointer-down),
            // release springs back with a tiny bounce (drag momentum).
            Item {
                id: thumb
                width: 18
                height: 18
                anchors.verticalCenter: track.verticalCenter
                x: root.trackLeft - thumb.width / 2 + root.normalized * root.trackWidth

                Behavior on x {
                    enabled: root.springEnabled && !root.dragging
                    SpringAnimation {
                        spring: 2.5
                        damping: 0.9
                        epsilon: 0.02
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.interactive ? root.accent : Theme.tokens.color.textSecondary
                    border.width: 1
                    border.color: root.interactive
                        ? Qt.lighter(root.accent, 1.6)
                        : "transparent"
                    scale: root.dragging ? 1.18 : 1.0

                    Behavior on scale {
                        enabled: root.springEnabled
                        SpringAnimation {
                            spring: 3.0
                            damping: 0.7
                            epsilon: 0.02
                        }
                    }

                    // Glass rim: bright top edge = light catching the material
                    // (apple-design §12), hidden in Safe tier.
                    Rectangle {
                        visible: Theme.visualQuality !== "safe"
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 2
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        height: 1
                        radius: 1
                        color: Qt.rgba(1, 1, 1, 0.55)
                    }
                }
            }

            // Value bubble: glass pill, scale-in from 0.95 + fade (never from
            // scale(0)); fades out quickly so drag stays 1:1 and snappy.
            Rectangle {
                id: bubble
                width: 52
                height: 24
                radius: 12
                anchors.bottom: track.top
                anchors.bottomMargin: 6
                x: Math.max(
                    0,
                    Math.min(
                        gestureArea.width - bubble.width,
                        root.thumbCenterX - bubble.width / 2
                    )
                )
                color: Theme.tokens.color.bgSurface
                border.color: Theme.tokens.color.border
                border.width: 1
                opacity: root.interactive && (root.dragging || root.showValue) ? 1.0 : 0.0
                scale: root.interactive && (root.dragging || root.showValue) ? 1.0 : 0.95

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.springEnabled ? 110 : 0
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    enabled: root.springEnabled
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.formatValue()
                    font.pixelSize: 10
                    font.family: Theme.tokens.font.mono
                    color: Theme.tokens.color.textPrimary
                }
                LiquidLights {
                    anchors.fill: parent
                    radius: 12
                    edgeLightOpacity: parseFloat(Theme.tokens.material.cardEdgeLight)
                    innerShadowOpacity: parseFloat(Theme.tokens.material.cardInnerShadow)
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                enabled: root.interactive
                hoverEnabled: true
                cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: root.setFromPointer(mouse.x)
                onPositionChanged: {
                    if (root.dragging) {
                        root.setFromPointer(mouse.x)
                    }
                }
            }
        }
    }
}
