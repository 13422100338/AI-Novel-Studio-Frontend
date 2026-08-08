import QtQuick
import QtQuick.Window

// BlockHelm Parity Mode (diagnosis only, per
// AI-Novel-Studio-BlockHelm-Parity-Mode-DeepSeek诊断实施指南-v0.1.md).
//
// Purpose: answer ONE question - can Qt Quick reach the visual result of the
// user-approved WPF BlockHelm demo under identical minimal conditions?
//
// This page is deliberately "ugly but pure":
//   - only DWM Acrylic + neutral-gray translucent rectangles;
//   - NO Theme tokens, NO BackdropLayer, NO glow, NO blur effects, NO
//     WebEngine, NO brand styling;
//   - fixed neutral palette (see _NS_* colors below).
//
// Modes (top buttons):
//   A solid      - opaque gray window, DWM none            (visual baseline)
//   B transparent- Qt alpha surface, DWM none              (Qt alpha alone)
//   C acrylic    - DWM Acrylic, only a status text visible (DWM output only)
//   D parity     - DWM Acrylic + neutral gray cards        (compare to WPF demo)
Window {
    id: root
    objectName: "parityWindow"

    width: 1280
    height: 820
    minimumWidth: 960
    minimumHeight: 640
    visible: true
    title: "AI Novel Studio · BlockHelm Parity Test"
    flags: Qt.FramelessWindowHint
    color: root.mode === "solid"
        ? "#2E2E2E"
        : "transparent"

    // ---- Fixed neutral palette (never read from Theme) -------------------
    readonly property color _NS_WASH:   "#6E6E6E"
    readonly property color _NS_PANEL:  "#D2D2D2"
    readonly property color _NS_SIDEBAR:"#5A5A5A"
    readonly property color _NS_BORDER: "#FFFFFF"
    readonly property color _NS_TEXT:   "#FFFFFF"
    readonly property real _WASH_A: 0.12
    readonly property real _PANEL_A: 0.45
    readonly property real _SIDEBAR_A: 0.52
    readonly property real _BORDER_A: 0.15

    // ---- Mode state -------------------------------------------------------
    property string mode: "parity"   // solid | transparent | acrylic | parity
    property string statusReason: ""
    readonly property bool nativeActive:
        typeof NativeGlassBridge !== "undefined" && NativeGlassBridge.nativeActive
    readonly property bool cardsVisible: root.mode === "parity"
    readonly property bool statusOnly: root.mode === "acrylic"

    function setMode(next: string) {
        root.mode = next
        if (typeof NativeGlassBridge === "undefined") {
            root.statusReason = "bridge 未注册"
            return
        }
        if (next === "solid" || next === "transparent") {
            NativeGlassBridge.apply("none")
        } else {
            NativeGlassBridge.apply("acrylic")
        }
        root.statusReason = ""
    }

    // Test/programmatic entry point (buttons call this too).
    function selectMode(key: string) {
        root.setMode(key)
    }

    // DWM first-show race retry (same bounded policy as the lab).
    property int retryCount: 0
    Timer {
        interval: 300
        repeat: true
        running: root.visible && root.mode !== "solid"
            && root.mode !== "transparent" && !root.nativeActive
            && root.retryCount < 5
        onTriggered: {
            if (typeof NativeGlassBridge !== "undefined") {
                root.retryCount += 1
                if (NativeGlassBridge.refresh()) {
                    root.retryCount = 5
                }
            }
        }
    }
    onNativeActiveChanged: {
        if (root.nativeActive) {
            root.retryCount = 5
        }
    }

    // Window wash: light neutral tint over the DWM backdrop (fixed value).
    Rectangle {
        anchors.fill: parent
        visible: root.mode === "acrylic" || root.mode === "parity"
        color: Qt.rgba(root._NS_WASH.r, root._NS_WASH.g, root._NS_WASH.b, root._WASH_A)
    }

    // ---- Mode switcher ----------------------------------------------------
    Row {
        id: modeBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 8

        Repeater {
            model: [
                { key: "solid",       label: "A solid" },
                { key: "transparent", label: "B transparent" },
                { key: "acrylic",     label: "C acrylic" },
                { key: "parity",      label: "D parity" },
            ]
            delegate: Rectangle {
                objectName: "btn-" + modelData.key
                width: 118
                height: 30
                radius: 6
                color: root.mode === modelData.key
                    ? Qt.rgba(1, 1, 1, 0.32)
                    : Qt.rgba(1, 1, 1, 0.12)
                border.color: Qt.rgba(1, 1, 1, 0.18)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: "#FFFFFF"
                    font.pixelSize: 12
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.selectMode(modelData.key)
                }
            }
        }
    }

    // ---- Status text ------------------------------------------------------
    Text {
        id: statusText
        anchors.top: modeBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        visible: root.statusOnly
        text: {
            if (!root.nativeActive) {
                return "DWM Acrylic: INACTIVE" + (root.statusReason ? " · " + root.statusReason : "")
            }
            return "DWM Acrylic: ACTIVE · 本行以外区域保持透明"
        }
        color: "#FFFFFF"
        font.pixelSize: 13
    }

    // ---- Parity cards (mode D) --------------------------------------------
    // Layout mirrors the user-approved WPF demo: big panels, wide spacing,
    // low content density, no opaque editor area.
    Column {
        visible: root.cardsVisible
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        Text {
            text: "AI Novel Studio · Glass Parity Test"
            color: root._NS_TEXT
            font.pixelSize: 16
            font.bold: true
        }

        Row {
            width: parent.width
            height: 150
            spacing: 12
            Repeater {
                model: ["Card 1", "Card 2", "Card 3"]
                delegate: Rectangle {
                    width: (parent.width - 24) / 3
                    height: parent.height
                    radius: 12
                    color: Qt.rgba(root._NS_PANEL.r, root._NS_PANEL.g, root._NS_PANEL.b, root._PANEL_A)
                    border.color: Qt.rgba(root._NS_BORDER.r, root._NS_BORDER.g, root._NS_BORDER.b, root._BORDER_A)
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: root._NS_TEXT
                        font.pixelSize: 14
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: 180
            spacing: 12
            Rectangle {
                width: (parent.width - 12) * 0.66
                height: parent.height
                radius: 12
                color: Qt.rgba(root._NS_PANEL.r, root._NS_PANEL.g, root._NS_PANEL.b, root._PANEL_A)
                border.color: Qt.rgba(root._NS_BORDER.r, root._NS_BORDER.g, root._NS_BORDER.b, root._BORDER_A)
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "Large Card"
                    color: root._NS_TEXT
                    font.pixelSize: 14
                }
            }
            Rectangle {
                width: (parent.width - 12) * 0.34
                height: parent.height
                radius: 12
                color: Qt.rgba(root._NS_SIDEBAR.r, root._NS_SIDEBAR.g, root._NS_SIDEBAR.b, root._SIDEBAR_A)
                border.color: Qt.rgba(root._NS_BORDER.r, root._NS_BORDER.g, root._NS_BORDER.b, root._BORDER_A)
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "Account"
                    color: root._NS_TEXT
                    font.pixelSize: 14
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 110
            radius: 12
            color: Qt.rgba(root._NS_PANEL.r, root._NS_PANEL.g, root._NS_PANEL.b, root._PANEL_A)
            border.color: Qt.rgba(root._NS_BORDER.r, root._NS_BORDER.g, root._NS_BORDER.b, root._BORDER_A)
            border.width: 1
            Text {
                anchors.centerIn: parent
                text: "Bottom Card"
                color: root._NS_TEXT
                font.pixelSize: 14
            }
        }
    }
}
