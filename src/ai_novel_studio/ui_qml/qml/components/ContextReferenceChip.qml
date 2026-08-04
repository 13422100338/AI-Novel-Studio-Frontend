import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string label: ""
    property string preview: ""
    signal cleared()

    // Public sizing rule: the chip spans its host's width. Without this a
    // Rectangle has no implicitWidth (0), the inner RowLayout collapses and
    // the label/preview/close children all stack at x=0 and overlap.
    implicitWidth: parent ? parent.width : 320
    implicitHeight: 28
    radius: Theme.tokens.radius.r8
    color: Theme.tokens.color.bgSidebar
    border.color: Theme.tokens.color.accent
    border.width: 1

    // Prevent a jarring pop-in: the chip fades in/out when a selection
    // reference appears or is cleared. Occasional frequency, ease-out.
    Behavior on opacity {
        NumberAnimation {
            duration: Facade.reduceMotion ? 0 : 150
            easing.type: Easing.OutCubic
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 4
        spacing: 6

        Text {
            Layout.fillWidth: true
            text: "已引用 · " + root.label
            font.pixelSize: 11
            elide: Text.ElideRight
            // Force a single line: elide only applies on one line, and a
            // multi-line chapter label would otherwise overflow the chip.
            maximumLineCount: 1
            color: Theme.tokens.color.textPrimary
        }
        Text {
            Layout.fillWidth: true
            visible: root.preview !== ""
            text: root.preview
            font.pixelSize: 10
            elide: Text.ElideRight
            maximumLineCount: 1
            color: Theme.tokens.color.textSecondary
            // Responsive cap: the preview must never squeeze the chapter
            // label out of view in a narrow panel.
            Layout.maximumWidth: Math.max(48, Math.round(root.width * 0.4))
        }
        AppButton {
            text: "×"
            implicitWidth: 24
            implicitHeight: 22
            onClicked: root.cleared()
        }
    }
}
