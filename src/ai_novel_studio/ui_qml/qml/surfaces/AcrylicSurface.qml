import QtQuick
import QtQuick.Effects
import "../effects"

// Real-time Acrylic material for the Visual V0 lab evaluation (glass rework).
//
// Research-backed implementation:
// - NNGroup "Glassmorphism: Definition and Best Practices": real glass is
//   translucency x backdrop blur; blur must be strong enough (25-100 px) and
//   the background complex enough for the effect to read as glass.
// - Qt blog "Qt Quick and Blurred Panels": blur the content BEHIND the panel,
//   not the panel itself -- ShaderEffectSource(sourceItem, sourceRect) feeding
//   MultiEffect(blurEnabled, autoPaddingEnabled: false, blurMax).
// - PyHuskarUI HusAcrylic layering: luminosity + tint + tiled low-opacity
//   noise on top of the blur.
// - iOS 26 "Liquid Glass" layer stack (Apple HIG materials; cupertino_liquid_glass
//   0.6.x for Flutter; Floatica): blur + tint + saturation/vibrancy boost +
//   top/left edge light + bottom/right inner shadow + noise grain. Light mode
//   is matte & bright, dark mode is deep & contrasty.
// - User feedback: no painted diagonal specular sheen; the light source is the
//   BackdropLayer background glow. All glass panels share the same flat edge
//   treatment (1px border + LiquidLights, no drop shadow).
//
// Scope: this component is used by the standalone Visual V0 lab page only.
// The production shell keeps the simulated GlassSurface until the user
// confirms the direction (ideal-UI spec 4.2/15); Visual V4 is reserved for
// optional Windows Mica.
Item {
    id: root

    default property alias content: contentArea.data

    // The item blurred behind this panel. The caller passes a background layer
    // that must NOT contain this panel, so the ShaderEffectSource never
    // captures itself (recursion / feedback is impossible by construction).
    required property Item sourceItem

    property real radius: Theme.tokens.radius.r12
    // Opaque fallback (Native Glass Lab "solid" mode): when true the surface
    // renders as a plain opaque theme panel (no capture, no blur, no tint
    // translucency). Used only by the standalone experiment page; the
    // production shell keeps the existing Safe-tier behavior.
    property bool opaqueFallback: false
    // BlockHelm-style native glass: the shell window already carries the DWM
    // Desktop Acrylic backdrop, so this panel must NOT re-blur an in-app
    // backdrop. It renders as a translucent theme tint only, letting the
    // window-behind content show through the window-level material.
    property bool nativeGlassActive: false

    // ---------------------------------------------------------------------
    // Behavior / test hooks. Safe tier degrades to a fully opaque surface
    // (no ShaderEffectSource, no MultiEffect); Balanced/Premium enable the
    // real-time capture and blur while the panel is visible.
    // ---------------------------------------------------------------------
    readonly property bool effectActive:
        visible && !root.opaqueFallback && !root.nativeGlassActive
        && Theme.visualQuality !== "safe"
        && root.sourceItem !== null
    readonly property bool blurEnabled: root.effectActive
    readonly property rect captureRect: capture.sourceRect
    readonly property color fillColor:
        root.opaqueFallback || root.nativeGlassActive
            || Theme.visualQuality === "safe"
            ? Theme.tokens.color.bgSurface
            : Qt.rgba(tintBase.r, tintBase.g, tintBase.b, root.tintOpacity)
    // Native-glass fill: a translucent theme tint so text stays readable
    // while the DWM material shows the desktop/other windows behind it.
    readonly property color nativeGlassFill:
        !root.useNativeGlassOverride
            ? Theme.tokens.nativeGlass.panelTint
            : root.nativeGlassFillOverride
    // Callers can give a surface its own native fill (e.g. the manuscript
    // host uses the near-opaque editorTint; chrome uses the thin panelTint).
    property bool useNativeGlassOverride: false
    property color nativeGlassFillOverride: "transparent"

    property color tintBase: Theme.tokens.material.acrylicTint
    // Tier separation: Balanced keeps a more solid tint (glass reads as
    // "frosted"), Premium uses a thinner tint so the stronger blur and the
    // backdrop colors show through more.
    property real tintOpacity:
        Theme.visualQuality === "premium"
            ? parseFloat(Theme.tokens.material.glassTintPremium)
            : parseFloat(Theme.tokens.material.glassTintBalanced)
    property real blurMax:
        Theme.visualQuality === "premium"
            ? parseFloat(Theme.tokens.material.glassBlurPremium)
            : parseFloat(Theme.tokens.material.glassBlurBalanced)
    property real saturation: parseFloat(Theme.tokens.material.glassSaturation)
    property real brightness: parseFloat(Theme.tokens.material.glassBrightness)

    // Liquid Glass overlay strengths (iOS 26 research stack, specular sheen
    // removed per user feedback). Safe tier hides all overlay layers; Premium
    // is deliberately stronger than Balanced so the tier separation stays
    // visible in every theme, including light.
    readonly property real edgeLightOpacity:
        root.opaqueFallback || Theme.visualQuality === "safe" ? 0.0
            : Theme.visualQuality === "premium"
                ? parseFloat(Theme.tokens.material.glassEdgeLightPremium)
                : parseFloat(Theme.tokens.material.glassEdgeLightBalanced)
    readonly property real innerShadowOpacity:
        root.opaqueFallback || Theme.visualQuality === "safe" ? 0.0
            : Theme.visualQuality === "premium"
                ? parseFloat(Theme.tokens.material.glassInnerShadowPremium)
                : parseFloat(Theme.tokens.material.glassInnerShadowBalanced)

    // Keep the captured region glued to this panel inside the source layer.
    // Explicit recompute on every geometry/visibility change is deterministic;
    // QML bindings cannot reliably track mapToItem() results.
    function updateCaptureRect() {
        if (!root.sourceItem) {
            capture.sourceRect = Qt.rect(0, 0, 0, 0)
            return
        }
        const p = root.mapToItem(root.sourceItem, 0, 0)
        capture.sourceRect = Qt.rect(p.x, p.y, root.width, root.height)
    }

    onSourceItemChanged: root.updateCaptureRect()
    onXChanged: root.updateCaptureRect()
    onYChanged: root.updateCaptureRect()
    onWidthChanged: root.updateCaptureRect()
    onHeightChanged: root.updateCaptureRect()
    onVisibleChanged: root.updateCaptureRect()
    Component.onCompleted: root.updateCaptureRect()

    // Rounded-corner mask for the blurred pass (Qt blog "advanced case").
    Item {
        id: maskItem
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: root.radius
        }
    }

    // Captures the background layer area behind this panel. `enabled` keeps
    // the capture off entirely for Safe tier / hidden panels (performance
    // gate; the ideal-UI spec forbids idle GPU cost for unused effects).
    ShaderEffectSource {
        id: capture
        objectName: "acrylicCapture"
        anchors.fill: parent
        sourceItem: root.sourceItem
        visible: false
        enabled: root.effectActive
    }

    MultiEffect {
        id: blurEffect
        anchors.fill: parent
        source: capture
        enabled: root.effectActive
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: root.blurMax
        saturation: root.saturation
        brightness: root.brightness
        maskEnabled: true
        maskSource: maskItem
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }

    // Luminosity layer: simulates light scattering inside the material
    // (PyHuskarUI HusAcrylic keeps this between blur and tint).
    Rectangle {
        id: luminosity
        visible: root.effectActive
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(1, 1, 1, parseFloat(Theme.tokens.material.acrylicLuminosity))
    }

    Rectangle {
        id: fill
        anchors.fill: parent
        radius: root.radius
        color: root.nativeGlassActive ? root.nativeGlassFill : root.fillColor
        border.color: Theme.tokens.color.border
        border.width: 1

        // Top inner highlight: the light catching the material.
        Rectangle {
            visible: root.effectActive
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            height: 1
            color: Theme.tokens.material.glassBorderHighlight
            radius: 1
        }
        // Deeper bottom edge reads as the material's thickness.
        Rectangle {
            visible: root.effectActive
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottomMargin: 0
            height: 1
            color: Theme.tokens.material.glassBorderShadow
        }

        // Liquid Glass layer stack (iOS 26 research stack): top/left edge
        // light + bottom/right inner shadow. Shared LiquidLights component
        // paints them in one static Canvas clipped to the rounded rect, so
        // nothing leaks past the corners. No specular sheen (user feedback).
        LiquidLights {
            id: liquidLights
            objectName: "liquidLights"
            anchors.fill: parent
            anchors.margins: 1
            radius: root.radius
            edgeLightOpacity: root.edgeLightOpacity
            innerShadowOpacity: root.innerShadowOpacity
            visible: root.effectActive
        }

        NoiseOverlay {
            anchors.fill: parent
            anchors.margins: 1
            visible: root.effectActive
        }

        Item {
            id: contentArea
            anchors.fill: parent
        }
    }
}
