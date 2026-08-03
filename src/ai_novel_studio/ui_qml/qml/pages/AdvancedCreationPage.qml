import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: root
    objectName: "advancedCreationPage"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Text {
            text: "高级创作"
            font.pixelSize: 17
            font.bold: true
            color: Theme.tokens.color.textPrimary
        }

        TabBar {
            id: tabs
            Layout.fillWidth: true
            Repeater {
                model: ["伏笔与回收", "故事线", "时间线", "人物认知", "一致性审查", "影响分析"]
                delegate: TabButton {
                    text: modelData
                    width: implicitWidth
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabs.currentIndex

            EmptyState { title: "伏笔与回收"; body: "伏笔登记与回收追踪将在后续 Wave 接入。" }
            EmptyState { title: "故事线"; body: "多故事线视图将在后续 Wave 接入。" }
            EmptyState { title: "时间线"; body: "时间线与影响分析将在后续 Wave 接入。" }
            EmptyState { title: "人物认知"; body: "人物认知状态将在后续 Wave 接入。" }
            AuditPage {}
            EmptyState { title: "影响分析"; body: "改动影响分析将在后续 Wave 接入。" }
        }
    }
}
