import QtQuick

// BlockHelm-style "Image Mode" backdrop source (independent QML port of the
// documented technique, not copied source).
//
// The reference app separates two backdrop strategies:
//   Acrylic Mode -> Windows DWM system backdrop (tint + heavy blur; outlines
//                   of window-behind content are weak by design);
//   Image Mode   -> an in-app background image blurred by the compositor
//                   (VisualBrush + GaussianBlur in WPF; ShaderEffectSource +
//                   MultiEffect here), which keeps recognizable outlines.
//
// This component is the QML equivalent of ``ImageBackdropSource``: a shallow
// visual that renders a fixed high-contrast scene ("Mist Harbor lighthouse")
// so local Acrylic surfaces can sample it. Large geometry (moon, mountains,
// lighthouse, sea, ship) keeps its outline even after a 25-60 px blur, which
// is exactly what makes the internal-glass route read as glass.
Item {
    id: root

    // Fixed sample art palette (a background image, not a theme layer).
    property color skyTop: "#0b1e33"
    property color skyBottom: "#35506b"
    property color sea: "#0e1b2e"
    property color moon: "#f2e7c9"
    property color mountainFar: "#22364c"
    property color mountainNear: "#17293d"
    property color lighthouseBody: "#d9d2c2"
    property color lighthouseAccent: "#b5442f"
    property color beam: "#f6d878"
    property color ship: "#1c2733"

    Canvas {
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d")
            const w = width
            const h = height
            if (w <= 1 || h <= 1) {
                return
            }

            // --- Sky -----------------------------------------------------
            const sky = ctx.createLinearGradient(0, 0, 0, h * 0.58)
            sky.addColorStop(0, root.skyTop)
            sky.addColorStop(1, root.skyBottom)
            ctx.fillStyle = sky
            ctx.fillRect(0, 0, w, h)

            // --- Moon with a soft halo --------------------------------
            const moonX = w * 0.24
            const moonY = h * 0.18
            const moonR = Math.min(w, h) * 0.075
            ctx.globalAlpha = 0.35
            ctx.fillStyle = root.moon
            ctx.beginPath()
            ctx.arc(moonX, moonY, moonR * 2.2, 0, Math.PI * 2)
            ctx.fill()
            ctx.globalAlpha = 1
            ctx.fillStyle = root.moon
            ctx.beginPath()
            ctx.arc(moonX, moonY, moonR, 0, Math.PI * 2)
            ctx.fill()

            // --- Far mountains ------------------------------------------
            ctx.fillStyle = root.mountainFar
            ctx.beginPath()
            ctx.moveTo(0, h * 0.62)
            ctx.lineTo(w * 0.16, h * 0.46)
            ctx.lineTo(w * 0.32, h * 0.60)
            ctx.lineTo(w * 0.50, h * 0.42)
            ctx.lineTo(w * 0.68, h * 0.58)
            ctx.lineTo(w * 0.86, h * 0.44)
            ctx.lineTo(w, h * 0.60)
            ctx.lineTo(w, h * 0.66)
            ctx.lineTo(0, h * 0.66)
            ctx.closePath()
            ctx.fill()

            // --- Near mountains -----------------------------------------
            ctx.fillStyle = root.mountainNear
            ctx.beginPath()
            ctx.moveTo(0, h * 0.72)
            ctx.lineTo(w * 0.10, h * 0.58)
            ctx.lineTo(w * 0.24, h * 0.70)
            ctx.lineTo(w * 0.44, h * 0.55)
            ctx.lineTo(w * 0.62, h * 0.71)
            ctx.lineTo(w * 0.80, h * 0.60)
            ctx.lineTo(w, h * 0.72)
            ctx.lineTo(w, h * 0.76)
            ctx.lineTo(0, h * 0.76)
            ctx.closePath()
            ctx.fill()

            // --- Sea -----------------------------------------------------
            ctx.fillStyle = root.sea
            ctx.fillRect(0, h * 0.76, w, h * 0.24)

            // Moonlight column on the water.
            ctx.globalAlpha = 0.28
            ctx.fillStyle = root.moon
            ctx.fillRect(moonX - moonR * 0.55, h * 0.78, moonR * 1.1, h * 0.20)
            ctx.globalAlpha = 1

            // Ripple lines.
            ctx.strokeStyle = Qt.rgba(0.88, 0.86, 0.78, 0.35)
            ctx.lineWidth = Math.max(1, h * 0.003)
            for (let i = 0; i < 5; i++) {
                const y = h * (0.80 + i * 0.045)
                ctx.beginPath()
                ctx.moveTo(w * 0.10, y)
                ctx.lineTo(w * 0.90, y)
                ctx.stroke()
            }

            // --- Lighthouse (right-of-center) ----------------------------
            const baseX = w * 0.68
            const baseY = h * 0.76
            const towerW = Math.min(w, h) * 0.085
            const towerH = h * 0.26
            // Body (tapered tower).
            ctx.fillStyle = root.lighthouseBody
            ctx.beginPath()
            ctx.moveTo(baseX - towerW * 0.55, baseY)
            ctx.lineTo(baseX - towerW * 0.28, baseY - towerH)
            ctx.lineTo(baseX + towerW * 0.28, baseY - towerH)
            ctx.lineTo(baseX + towerW * 0.55, baseY)
            ctx.closePath()
            ctx.fill()
            // Red band.
            ctx.fillStyle = root.lighthouseAccent
            ctx.fillRect(
                baseX - towerW * 0.47,
                baseY - towerH * 0.55,
                towerW * 0.94,
                towerH * 0.16
            )
            // Lantern room.
            ctx.fillStyle = root.lighthouseAccent
            ctx.fillRect(
                baseX - towerW * 0.32,
                baseY - towerH * 1.08,
                towerW * 0.64,
                towerH * 0.12
            )
            // Light beam to the right.
            ctx.globalAlpha = 0.45
            ctx.fillStyle = root.beam
            ctx.beginPath()
            ctx.moveTo(baseX + towerW * 0.28, baseY - towerH * 1.02)
            ctx.lineTo(w * 0.98, baseY - towerH * 0.74)
            ctx.lineTo(w * 0.98, baseY - towerH * 1.12)
            ctx.closePath()
            ctx.fill()
            ctx.globalAlpha = 1
            ctx.fillStyle = root.beam
            ctx.beginPath()
            ctx.arc(baseX, baseY - towerH * 1.02, towerW * 0.10, 0, Math.PI * 2)
            ctx.fill()

            // --- Ship silhouette (lower right) ---------------------------
            ctx.fillStyle = root.ship
            ctx.beginPath()
            ctx.moveTo(w * 0.84, h * 0.86)
            ctx.lineTo(w * 0.74, h * 0.86)
            ctx.lineTo(w * 0.78, h * 0.82)
            ctx.lineTo(w * 0.82, h * 0.82)
            ctx.closePath()
            ctx.fill()
            ctx.fillRect(w * 0.78, h * 0.74, w * 0.008, h * 0.08)
            ctx.beginPath()
            ctx.moveTo(w * 0.785, h * 0.76)
            ctx.lineTo(w * 0.815, h * 0.76)
            ctx.lineTo(w * 0.80, h * 0.70)
            ctx.closePath()
            ctx.fill()
        }
    }
}
