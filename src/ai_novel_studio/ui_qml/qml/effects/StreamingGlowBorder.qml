import QtQuick

// StreamingGlowBorder — neon energy flow around the *currently active* Agent
// surface (redesigned per user direction, glassmorphism-ui-log.md §24).
//
// A light point with a fading tail and a soft halo travels the FULL rounded
// rectangle perimeter at constant speed, like energy flowing in a neon tube:
//   - one Canvas overlay paints the whole effect in a single pass: the bright
//     core (~4-8px), a ~20-40px tail with exponential falloff sampled behind
//     the point, and a low-alpha outer halo. No solid capsule, no top bar.
//   - position/tangent come from a perimeter parameterization (pathPoint /
//     pathAngle over the 4 straight edges and 4 corner arcs), so the light
//     hugs the border centerline and passes top, right, bottom and left.
//   - the overlay only covers the card, never participates in layout and
//     never touches width/height/implicitHeight; no MouseArea, so content and
//     buttons stay interactive and uncovered.
//   - state machine: thinking/generating loop; success/error sweep once;
//     cancelled fades out once; idle = plain static border.
//   - animations stop when hidden, window minimized, or reduceMotion.
//   - Safe tier / missing Facade degrade to the static highlight border.
Item {
    id: root

    property bool active: false
    // "" | "thinking" | "generating" | "success" | "error" | "cancelled" |
    // "idle"
    property string state: ""
    property real radius: 12
    property real glowWidth: 1.5

    // Neon parameters: core diameter ~4-8px, tail ~20-40px, halo ~8-12px.
    property real coreRadius: 3.0
    property real tailLength: 30
    property real haloRadius: 10
    property int tailSamples: 24
    property int flowDuration: 2200
    property int fadeDuration: 700

    // Guarded Facade access (context property can be null early; `=== null`
    // is unreliable for QObject context values — see §18.2).
    readonly property bool reduce:
        typeof Facade !== "undefined" && Facade ? Facade.reduceMotion : false
    readonly property bool windowVisible:
        typeof root.window === "undefined" || root.window === null
            ? true
            : root.window.visible

    // State machine ------------------------------------------------
    readonly property bool looping:
        root.active
        && (root.state === "" || root.state === "thinking"
            || root.state === "generating")
    readonly property bool singleShot:
        root.active
        && (root.state === "success" || root.state === "error")
    readonly property bool fadingOut:
        root.active && root.state === "cancelled"
    readonly property bool idleStatic:
        !root.active || root.state === "idle" || root.reduce
        || !root.windowVisible

    // The flowing layer is painted only while all conditions hold.
    readonly property bool neonActive:
        root.active
        && root.visible
        && !root.reduce
        && root.windowVisible
        && !root.singleFinished
        && !root.cancelFaded

    // Animation/test hooks -----------------------------------------
    readonly property bool animationRunning: flowAnim.running || singleAnim.running
    readonly property bool loopAnimRunning: flowAnim.running
    readonly property bool fadeAnimRunning: fadeAnim.running
    // Test/behavior hook: the live static border color.
    readonly property color frameColor: frame.border.color
    property bool singleFinished: false
    property bool cancelFaded: false
    property real phase: 0.0
    // Test hook: canvas repaint counter (proves the overlay repaints as the
    // phase advances).
    property int paintCount: 0

    onStateChanged: {
        root.singleFinished = false
        root.cancelFaded = false
    }

    // Perimeter parameterization ------------------------------------
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

    // Static fallback border (Safe / reduceMotion / idle / shader n/a).
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

    // Neon overlay: one Canvas paints core + tail + halo in a single pass.
    Canvas {
        id: neonCanvas
        objectName: "neonOverlay"
        anchors.fill: parent
        visible: root.neonActive
        enabled: root.neonActive

        onWidthChanged: neonCanvas.requestPaint()
        onHeightChanged: neonCanvas.requestPaint()

        onPaint: {
            root.paintCount += 1
            const ctx = neonCanvas.getContext("2d")
            ctx.reset()
            const w = neonCanvas.width
            const h = neonCanvas.height
            if (w < 4 || h < 4) {
                return
            }
            const r = Math.min(root.radius, w / 2, h / 2)
            const center = root.pathPoint(root.phase, w, h, r)
            const angleRad = root.pathAngle(root.phase) * Math.PI / 180
            const tx = Math.cos(angleRad)
            const ty = Math.sin(angleRad)
            const c = root.staticColor
            const col = function (alpha) {
                return "rgba("
                    + Math.round(c.r * 255) + ","
                    + Math.round(c.g * 255) + ","
                    + Math.round(c.b * 255) + ","
                    + alpha.toFixed(3) + ")"
            }

            // Low-alpha outer halo (soft, no solid capsule).
            ctx.fillStyle = col(0.14)
            ctx.beginPath()
            ctx.arc(center.x, center.y, root.haloRadius, 0, 2 * Math.PI)
            ctx.fill()

            // Fading tail behind the point (exponential falloff, shrinks).
            for (let i = 1; i <= root.tailSamples; i++) {
                const k = i / root.tailSamples
                const dist = k * root.tailLength
                const px = center.x - tx * dist
                const py = center.y - ty * dist
                const alpha = 0.55 * Math.pow(1 - k, 1.8)
                const rad = root.coreRadius * (1 - 0.35 * k)
                ctx.fillStyle = col(alpha)
                ctx.beginPath()
                ctx.arc(px, py, Math.max(0.6, rad), 0, 2 * Math.PI)
                ctx.fill()
            }

            // Bright core (~4-8px), state-colored, never whitened.
            ctx.fillStyle = col(1.0)
            ctx.beginPath()
            ctx.arc(center.x, center.y, root.coreRadius, 0, 2 * Math.PI)
            ctx.fill()
        }
    }

    // Keep repainting every frame while the neon is live. The NumberAnimation
    // drives `phase`; this tick is a belt-and-braces repaint trigger so the
    // overlay always follows the phase even on renderers where a binding-only
    // requestPaint would be coalesced.
    Timer {
        id: repaintTick
        interval: 16
        repeat: true
        running: root.neonActive
        onTriggered: neonCanvas.requestPaint()
    }

    onPhaseChanged: {
        if (root.neonActive) {
            neonCanvas.requestPaint()
        }
    }

    // Loop: thinking / generating keep flowing.
    NumberAnimation {
        id: flowAnim
        target: root
        property: "phase"
        from: 0
        to: 1
        duration: root.flowDuration
        loops: Animation.Infinite
        running: root.looping && root.neonActive
        easing.type: Easing.Linear
    }

    // Single sweep: success / error play once and stop.
    NumberAnimation {
        id: singleAnim
        target: root
        property: "phase"
        from: 0
        to: 1
        duration: root.flowDuration
        loops: 1
        running: root.singleShot && root.neonActive && !root.singleFinished
        easing.type: Easing.Linear
        onFinished: root.singleFinished = true
    }

    // Cancelled: fade the neon out once, then stay gone.
    NumberAnimation {
        id: fadeAnim
        target: neonCanvas
        property: "opacity"
        from: 1.0
        to: 0.0
        duration: root.fadeDuration
        loops: 1
        running: root.fadingOut && root.neonActive && !root.cancelFaded
        easing.type: Easing.OutCubic
        onFinished: root.cancelFaded = true
    }
}
