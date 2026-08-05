import QtQuick

// Restrained "streaming" border (ideal-UI spec 8): a slow 2.8s hue drift on a
// 1.5px hairline around the *currently active* Agent card. One or two live
// instances at most; success/error/cancelled snap to their static state color.
// reduceMotion degrades to a static highlight (no movement, no flicker).
//
// Comet highlight (user request, glassmorphism-ui-log.md §22): a brighter,
// whitened point travels along the border at constant speed, one lap per
// ~2.2s, for thinking/cancelled/error states. The core is near-white and the
// halo blends the state color so it reads as light running around the edge.
// reduceMotion keeps a single static highlight at the top edge (gentler, not
// zero — apple-design §14).
Item {
    id: root

    property bool active: false
    property string state: "" // "" | success | error | cancelled
    property real radius: 12
    property real glowWidth: 1.5

    // Guarded like AppButton: the Facade context property can be null during
    // early binding; `=== null` is unreliable for QObject context values, so
    // use typeof + truthiness (see §18.2).
    readonly property bool reduce:
        typeof Facade !== "undefined" && Facade ? Facade.reduceMotion : false
    readonly property bool running:
        root.active && !root.reduce && root.visible && root.state === ""
    // Test/behavior hook: expose whether the drift animation is live so QML
    // tests can assert reduceMotion degrades to a static highlight.
    readonly property bool animationRunning: glowAnim.running
    // Test/behavior hook: expose the live border color.
    readonly property color frameColor: frame.border.color
    // Test/behavior hook: whether the comet lap animation is live.
    readonly property bool cometAnimRunning: cometAnim.running
    // Test/behavior hook: whether the comet should travel (visible + active +
    // motion allowed).
    readonly property bool cometRunning:
        root.active && !root.reduce && root.visible

    // Comet progress 0..1 (one full lap around the rounded-rect border).
    // Exposed so tests can assert the path function and screenshots can park
    // the comet at a known position.
    property real cometProgress: 0.0
    property real cometCoreRadius: 2.2
    property real cometHaloRadius: 7
    property int cometDuration: 2200
    // Test hook: how many times the comet canvas repainted.
    // Comet visual position (card-local), driven by property bindings so the
    // render pipeline repaints on every progress change without a manual
    // requestPaint (which does not follow animations on software rendering).
    readonly property real cometVisualX: root.cometPosition(root.cometProgress).x
    readonly property real cometVisualY: root.cometPosition(root.cometProgress).y

    // Path sampling: split the rounded-rect perimeter into segments and walk
    // them; returns the point at `progress` (0..1) on the border centerline.
    // Pure functions on the root so tests can call them from this scope.
    function pathPoint(t, w, h, r) {
        const pi = Math.PI
        const straight = Math.max(0, w - 2 * r)
        const vertical = Math.max(0, h - 2 * r)
        const arc = (pi / 2) * r
        const segs = [
            straight, arc, vertical, arc,
            straight, arc, vertical, arc
        ]
        const perimeter = segs[0] + segs[1] + segs[2] + segs[3]
            + segs[4] + segs[5] + segs[6] + segs[7]
        let remaining = (t * perimeter) % perimeter
        let index = 0
        while (index < 8 && remaining > segs[index]) {
            remaining -= segs[index]
            index += 1
        }
        const frac = segs[index] > 0 ? remaining / segs[index] : 0
        const corners = [
            { x: r, y: r },           // top-left center
            { x: w - r, y: r },       // top-right center
            { x: w - r, y: h - r },   // bottom-right center
            { x: r, y: h - r }        // bottom-left center
        ]
        const cornerAngles = [
            { from: -pi / 2, to: 0 },       // top-left -> top-right arc
            { from: 0, to: pi / 2 },        // top-right -> bottom-right
            { from: pi / 2, to: pi },       // bottom-right -> bottom-left
            { from: pi, to: 3 * pi / 2 }    // bottom-left -> top-left
        ]
        // The arc segments follow their *destination* corner: seg1 ends at the
        // top-right corner, seg3 at bottom-right, seg5 at bottom-left, seg7
        // back at top-left. Using the start corner made the first arc double
        // back to the top-left (visible fold-back at ~0.33 of the lap).
        const cornerIndex = (Math.floor(index / 2) + 1) % 4
        const c = corners[cornerIndex]
        if (index % 2 === 1) {
            const a = cornerAngles[cornerIndex]
            const angle = a.from + (a.to - a.from) * frac
            return Qt.point(
                c.x + r * Math.cos(angle),
                c.y + r * Math.sin(angle)
            )
        }
        if (index === 0) {
            return Qt.point(r + straight * frac, 0)
        }
        if (index === 2) {
            return Qt.point(w, r + vertical * frac)
        }
        if (index === 4) {
            return Qt.point(w - r - straight * frac, h)
        }
        return Qt.point(0, h - r - vertical * frac)
    }

    function cometPosition(progress) {
        const w = root.width
        const h = root.height
        const r = Math.min(root.radius, w / 2, h / 2)
        return root.pathPoint(
            Math.max(0, Math.min(1, progress)),
            w,
            h,
            r
        )
    }

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

    // The comet: a bright whitened point traveling along the border. Built
    // from three concentric circles (halo / mid / white core) and moved via a
    // transform.translate driven by bindings — the render pipeline repaints
    // automatically (a Canvas requestPaint does not follow animations on
    // software rendering), no layout property animates and the loop is
    // constant-speed (linear).
    Item {
        id: cometVisual
        objectName: "streamingComet"
        width: root.cometHaloRadius * 2
        height: root.cometHaloRadius * 2
        visible: root.active

        transform: Translate {
            id: cometTranslate
            x: root.cometVisualX - cometVisual.width / 2
            y: root.cometVisualY - cometVisual.height / 2
        }

        // Outer halo: state color at low alpha.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(
                root.staticColor.r,
                root.staticColor.g,
                root.staticColor.b,
                0.40
            )
        }
        // Mid glow: whitened state color, brighter toward the core.
        Rectangle {
            anchors.centerIn: parent
            width: root.cometHaloRadius * 1.15
            height: root.cometHaloRadius * 1.15
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.55)
        }
        // Bright near-white core: the 泛白 point of the highlight.
        Rectangle {
            anchors.centerIn: parent
            width: root.cometCoreRadius * 2
            height: root.cometCoreRadius * 2
            radius: width / 2
            color: "white"
        }
    }

    NumberAnimation {
        id: cometAnim
        target: root
        property: "cometProgress"
        from: 0
        to: 1
        duration: root.cometDuration
        loops: Animation.Infinite
        running: root.cometRunning
        easing.type: Easing.Linear
    }
}
