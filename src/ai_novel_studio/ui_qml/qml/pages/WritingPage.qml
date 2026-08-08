import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../surfaces"

Item {
    id: root

    property bool useWebEngine: false
    property string lastEditorChapterId: ""
    // DWM Desktop Acrylic is active on the shell window: drop the opaque page
    // backdrop so the window-behind content shows through (BlockHelm-style).
    property bool nativeGlassActive: false
    // Window backdrop passed from the shell; the manuscript host becomes an
    // Acrylic surface over it (same glass language as nav/sidebar/dock).
    property Item backdropSource: null

    Rectangle {
        anchors.fill: parent
        color: root.nativeGlassActive
            ? "transparent" : Theme.tokens.color.bgCanvas
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: Facade.currentVolumeTitle
                    font.pixelSize: 11
                    color: Theme.tokens.color.textSecondary
                }
                Text {
                    Layout.fillWidth: true
                    text: Facade.currentChapterTitle
                    font.pixelSize: 17
                    font.bold: true
                    elide: Text.ElideRight
                    color: Theme.tokens.color.textPrimary
                }
            }

            AppButton {
                objectName: "chapterMenuButton"
                text: "···"
                onClicked: chapterMenu.popup()
            }
        }

        Menu {
            id: chapterMenu
            objectName: "chapterMenu"

            MenuItem {
                text: "修订 " + Facade.currentRevision
                enabled: false
            }
            MenuItem {
                text: "章节信息"
                onTriggered: Facade.setSaveStatusText("章节信息面板将在后续 Wave 接线。")
            }
            MenuItem {
                objectName: "generateDraftMenuItem"
                text: "生成草稿"
                enabled: Facade.draftStatus !== "GENERATING" && Facade.draftStatus !== "QUEUED"
                onTriggered: generationDialog.openRequested = true
            }
            MenuItem {
                objectName: "aiAssistantMenuItem"
                text: "AI 助手"
                onTriggered: Facade.toggleAiDrawer(true)
            }
        }

        // Manuscript host: glass panel over the shared backdrop. In TextArea
        // mode the editor sits directly on the glass; in WebEngine mode the
        // page background (theme-synced) stays opaque on top for readability
        // while the rounded rim and glow read as glass.
        AcrylicSurface {
            objectName: "manuscriptHost"
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.tokens.radius.r16
            sourceItem: root.backdropSource
            nativeGlassActive: root.nativeGlassActive
            useNativeGlassOverride: root.nativeGlassActive
            nativeGlassFillOverride: Theme.tokens.nativeGlass.editorTint
            clip: true

            ScrollView {
                visible: !root.useWebEngine
                anchors.fill: parent
                anchors.margins: 12

                TextArea {
                    id: editor
                    objectName: "manuscriptEditor"
                    text: Facade.currentChapterBody
                    font.family: Theme.tokens.font.manuscript
                    font.pixelSize: 15
                    color: Theme.tokens.color.textPrimary
                    selectionColor: Theme.tokens.color.accent
                    selectedTextColor: "white"
                    wrapMode: TextEdit.Wrap
                    background: null
                    placeholderText: "开始写作…"
                    placeholderTextColor: Theme.tokens.color.textSecondary
                    onTextChanged: Facade.editorTextChanged(editor.text)
                }
            }

            Loader {
                id: webEditorLoader
                anchors.fill: parent
                anchors.margins: 12
                active: root.useWebEngine

                sourceComponent: NovelEditorView {
                    id: webEditor
                    objectName: "novelEditorView"
                    editorUrl: EditorAssets.indexUrl
                    // Static: QtWebEngine must not re-bind its canvas color to
                    // the live bridge (crashes on capability emit). The
                    // manuscript host around it is the glass; the editor
                    // sheet stays on the theme editor color for readability.
                    editorSurfaceColor: Theme.tokens.color.bgEditor

                    function loadCurrentChapter() {
                        var payload = {
                            chapterId: Facade.currentChapterId,
                            baseRevision: Facade.currentRevision,
                            markdown: Facade.currentChapterBody
                        }
                        webEditor.loadChapter(JSON.stringify(payload))
                    }

                    onEditorLoaded: {
                        root.lastEditorChapterId = Facade.currentChapterId
                        webEditor.loadCurrentChapter()
                    }

                    Connections {
                        target: Facade
                        function onDraftAcceptedToEditor(markdown) {
                            if (webEditorLoader.item !== null) {
                                webEditorLoader.item.loadChapter(
                                    JSON.stringify({
                                        chapterId: Facade.currentChapterId,
                                        baseRevision: Facade.currentRevision,
                                        markdown: markdown
                                    })
                                )
                            }
                        }
                        function onEditorRevisionChanged(revision) {
                            if (webEditorLoader.item !== null) {
                                webEditorLoader.item.setBaseRevision(revision)
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StatusChip {
                label: "字数"
                value: root.useWebEngine ? Facade.webEngineWordCountText : Facade.currentWordCountText
                tone: "accent"
            }
            StatusChip {
                label: "状态"
                value: root.statusText(Facade.editorState)
                tone: root.stateTone(Facade.editorState)
            }
            StatusChip {
                label: "修订"
                value: String(Facade.currentRevision)
            }
            StatusChip {
                label: ""
                value: Facade.saveStatusText
                visible: Facade.editorState !== "CLEAN"
            }

            Item {
                Layout.fillWidth: true
            }

            AppButton {
                objectName: "reloadButton"
                text: "放弃本地修改并重新载入"
                visible: Facade.editorState === "CONFLICT"
                onClicked: Facade.reloadChapter()
            }
            AppButton {
                objectName: "saveButton"
                text: "保存"
                primary: true
                onClicked: {
                    if (root.useWebEngine) {
                        if (webEditorLoader.item !== null) {
                            webEditorLoader.item.requestSave()
                        }
                    } else {
                        Facade.requestSave()
                    }
                }
            }
            AppButton {
                objectName: "cancelDraftButton"
                text: "取消生成"
                visible: Facade.draftStatus === "GENERATING" || Facade.draftStatus === "QUEUED"
                onClicked: Facade.cancelDraft()
            }
        }
    }

    function statusText(state) {
        if (state === "DIRTY") return "编辑中"
        if (state === "SAVING") return "保存中"
        if (state === "CONFLICT") return "修订冲突"
        return "已保存"
    }

    function stateTone(state) {
        if (state === "DIRTY") return "warning"
        if (state === "SAVING") return "accent"
        if (state === "CONFLICT") return "danger"
        return "success"
    }

    GenerationConfigDialog {
        id: generationDialog
        parent: root
        anchors.centerIn: parent
    }

    function revealEvidence(position, length) {
        if (root.useWebEngine) {
            if (webEditorLoader.item !== null) {
                webEditorLoader.item.revealRange(position, position + length)
            }
            return
        }
        editor.forceActiveFocus()
        editor.select(position, position + length)
    }

    function reloadFromFacade() {
        if (root.useWebEngine && webEditorLoader.item !== null) {
            webEditorLoader.item.loadCurrentChapter()
        }
    }
}
