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
    property bool elevated: true

    // ---------------------------------------------------------------------
    // Behavior / test hooks. Safe tier degrades to a fully opaque surface
    // (no ShaderEffectSource, no MultiEffect); Balanced/Premium enable the
    // real-time capture and blur while the panel is visible.
    // ---------------------------------------------------------------------
    readonly property bool effectActive:
        visible && Theme.visualQuality !== "safe" && root.sourceItem !== null
    readonly property bool blurEnabled: root.effectActive
    readonly property rect captureRect: capture.sourceRect
    readonly property color fillColor:
        Theme.visualQuality === "safe"
            ? Theme.tokens.color.bgSurface
            : Qt.rgba(tintBase.r, tintBase.g, tintBase.b, root.tintOpacity)

    property color tintBase: Theme.tokens.material.acrylicTint
    property real tintOpacity: parseFloat(Theme.tokens.material.glassTintOpacity)
    property real blurMax:
        Theme.visualQuality === "premium"
            ? parseFloat(Theme.tokens.material.glassBlurPremium)
            : parseFloat(Theme.tokens.material.glassBlurBalanced)
    property real saturation: parseFloat(Theme.tokens.material.glassSaturation)
    property real brightness: parseFloat(Theme.tokens.material.glassBrightness)

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

    // Static soft shadow (Safe tier may keep static shadows; no blur/shader).
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        radius: root.radius + 2
        color: "transparent"
        border.width: root.elevated ? 5 : 3
        border.color: Theme.tokens.elevation.shadowSoft
        z: -1
    }

    // Captures the background layer area behind this panel. `enabled` keeps
    // the capture off entirely for Safe tier / hidden panels (performance
    // gate; the ideal-UI spec forbids idle GPU cost for unused effects).
    ShaderEffectSource {
        id: capture
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
        color: root.fillColor
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

        NoiseOverlay {
            anchors.fill: parent
            anchors.margins: 1
        }

        Item {
            id: contentArea
            anchors.fill: parent
        }
    }
}
