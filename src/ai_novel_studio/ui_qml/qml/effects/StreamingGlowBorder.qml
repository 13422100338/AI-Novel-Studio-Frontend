import QtQuick

// Restrained "streaming" border (ideal-UI spec 8): a slow 2.8s hue drift on a
// 1.5px hairline around the *currently active* Agent card. One or two live
// instances at most; success/error/cancelled snap to their static state color.
// reduceMotion degrades to a static highlight (no movement, no flicker).
Item {
    id: root

    property bool active: false
    property string state: "" // "" | success | error | cancelled
    property real radius: 12
    property real glowWidth: 1.5

    readonly property bool reduce: Facade.reduceMotion
    readonly property bool running:
        root.active && !root.reduce && root.visible && root.state === ""
    // Test/behavior hook: expose whether the drift animation is live so QML
    // tests can assert reduceMotion degrades to a static highlight.
    readonly property bool animationRunning: glowAnim.running
    // Test/behavior hook: expose the live border color.
    readonly property color frameColor: frame.border.color

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: root.active ? root.glowWidth : 0
        border.color: root.staticColor
    }

    readonly property color staticColor: {
        if (!root.active) {
            return "transparent"
        }
        if (root.state === "success") {
            return Theme.tokens.agent.success
        }
        if (root.state === "error") {
            return Theme.tokens.agent.error
        }
        if (root.state === "cancelled") {
            return Theme.tokens.agent.cancelled
        }
        return Theme.tokens.agent.thinkingA
    }

    SequentialAnimation {
        id: glowAnim
        running: root.running
        loops: Animation.Infinite
        ColorAnimation {
            target: frame
            property: "border.color"
            from: Theme.tokens.agent.thinkingA
            to: Theme.tokens.agent.thinkingB
            duration: Theme.tokens.motion.glowCycle / 2
            easing.type: Easing.InOutSine
        }
        ColorAnimation {
            target: frame
            property: "border.color"
            from: Theme.tokens.agent.thinkingB
            to: Theme.tokens.agent.thinkingA
            duration: Theme.tokens.motion.glowCycle / 2
            easing.type: Easing.InOutSine
        }
    }
}
