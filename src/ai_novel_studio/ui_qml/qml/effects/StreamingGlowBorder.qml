import QtQuick

// Restrained "streaming" border (ideal-UI spec 8): a slow 2.8s hue drift on a
// 1.5px hairline around the *currently active* Agent card. One or two live
// instances at most; success/error/cancelled snap to their static state color.
// reduceMotion degrades to a static highlight (no movement, no flicker).
//
// "Carriage" highlight (user clarification, glassmorphism-ui-log.md ?23):
// the state border is the track and a short capsule travels along it like a
// train car seen from above - its width is slightly wider than the 1.5px
// border, both ends taper back to the track (rounded capsule ends), and the
// shape breathes subtly (length/width/opacity micro-pulse) while moving.
// The capsule keeps the state color (slightly brightened), never whitened.
// reduceMotion freezes both the lap and the pulse (gentler, not zero).
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
    // Test/behavior hook: whether the capsule should travel (visible + active
    // + motion allowed).
    readonly property bool cometRunning:
        root.active && !root.reduce && root.visible

    // Carriage progress 0..1 (one full lap around the rounded-rect border)
    // and pulse phase 0..1 (one breathing cycle). Exposed so tests can assert
    // the path/angle functions and park the carriage at known positions.
    property real cometProgress: 0.0
    property real pulsePhase: 0.0
    property int cometDuration: 2200
    property int pulseDuration: 1500
    // Carriage dimensions: length along the track (~26px), breadth slightly
    // wider than the 1.5px border (3.5px -> ~1px overhang each side).
    property real carriageLength: 26
    property real carriageBreadth: 3.5
    // Breathing amplitude: breadth +-10%, length +-6%, opacity 0.85..1.0.
    property real pulseBreadthAmplitude: 0.10
    property real pulseLengthAmplitude: 0.06
    // Carriage visual geometry (card-local), driven by property bindings so
    // the render pipeline repaints on every progress change without a manual
    // requestPaint (which does not follow animations on software rendering).
    readonly property real cometVisualX: root.cometPosition(root.cometProgress).x
    readonly property real cometVisualY: root.cometPosition(root.cometProgress).y
    readonly property real cometVisualAngle: root.pathAngle(root.cometProgress)
    readonly property real cometVisualLength:
        root.carriageLength
        * (1 + root.pulseLengthAmplitude
            * Math.sin(root.pulsePhase * 2 * Math.PI + 0.5))
    readonly property real cometVisualBreadth:
        root.carriageBreadth
        * (1 + root.pulseBreadthAmplitude
            * Math.sin(root.pulsePhase * 2 * Math.PI))
    readonly property real cometVisualOpacity:
        0.85 + 0.15 * Math.sin(root.pulsePhase * 2 * Math.PI + 1.2)
    // Test/behavior hook: the carriage fill color (state color, slightly
    // brightened, never whitened).
    readonly property color cometColor:
        Qt.lighter(root.staticColor, 1.18)
    readonly property bool pulseAnimRunning: pulseAnim.running

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

    // Tangent angle (degrees, clockwise) at `progress` so the capsule stays
    // aligned with the track: straight edges are fixed (top 0, right 90,
    // bottom 180, left 270) and corner arcs rotate linearly between them.
    function pathAngle(t) {
        const w = root.width
        const h = root.height
        const r = Math.min(root.radius, w / 2, h / 2)
        const straight = Math.max(0, w - 2 * r)
        const vertical = Math.max(0, h - 2 * r)
        const arc = (Math.PI / 2) * r
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
        if (index === 0) {
            return 0
        }
        if (index === 1) {
            return 90 * frac
        }
        if (index === 2) {
            return 90
        }
        if (index === 3) {
            return 90 + 90 * frac
        }
        if (index === 4) {
            return 180
        }
        if (index === 5) {
            return 180 + 90 * frac
        }
        if (index === 6) {
            return 270
        }
        return 270 + 90 * frac
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

    // The carriage: a short capsule traveling along the border like a train
    // car on its track - length along the tangent, breadth a bit wider than
    // the border, rounded ends tapering back to the track, state-colored
    // (slightly brightened, never whitened) and breathing subtly. Driven by
    // bindings on x/y/rotation/width/height/opacity so the render pipeline
    // repaints automatically (Canvas requestPaint does not follow animations
    // on software rendering); no layout property animates.
    Item {
        id: cometVisual
        objectName: "streamingComet"
        visible: root.active
        x: root.cometVisualX - cometVisual.width / 2
        y: root.cometVisualY - cometVisual.height / 2
        width: root.cometVisualLength
        height: root.cometVisualBreadth
        rotation: root.cometVisualAngle
        opacity: root.cometVisualOpacity

        // Soft outer glow capsule: state color, wider than the track so the
        // carriage reads as slightly overhanging the rails.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(
                root.cometColor.r,
                root.cometColor.g,
                root.cometColor.b,
                0.30
            )
            scale: 1.55
        }
        // Solid carriage body: rounded ends taper back to the track.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.cometColor
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

    // Shape breathing: a separate, slower cycle that slightly changes the
    // carriage length/breadth/opacity while it travels (???????).
    NumberAnimation {
        id: pulseAnim
        target: root
        property: "pulsePhase"
        from: 0
        to: 1
        duration: root.pulseDuration
        loops: Animation.Infinite
        running: root.cometRunning
        easing.type: Easing.InOutSine
    }
}
