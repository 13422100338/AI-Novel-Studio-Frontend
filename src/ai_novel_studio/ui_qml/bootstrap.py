"""Application bootstrap for the QML shell (Frontend Wave F1)."""

from __future__ import annotations

import os
import sys
from collections.abc import Sequence
from pathlib import Path

from PySide6.QtCore import Property, QObject, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from ai_novel_studio.ui_qml.bridge.mock_novel_studio_facade import MockNovelStudioFacade
from ai_novel_studio.ui_qml.bridge.theme_provider import ThemeProvider
from ai_novel_studio.ui_qml.editor_runtime import ensure_editor_dist, ensure_qwebchannel_js

_FRONTEND_STATE: dict[int, tuple[MockNovelStudioFacade, ThemeProvider]] = {}


class EditorAssets(QObject):
    """Exposes the local editor page URL to QML (WebEngine mode)."""

    def __init__(self, index_url: str, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._index_url = index_url

    @Property(str, constant=True)
    def indexUrl(self) -> str:
        return self._index_url


def register_frontend_types(
    engine: QQmlApplicationEngine,
    facade: MockNovelStudioFacade | None = None,
    theme: ThemeProvider | None = None,
) -> tuple[MockNovelStudioFacade, ThemeProvider]:
    """Expose the two F1 singletons to QML.

    Context properties are used deliberately instead of ``qmlRegisterSingletonType``:
    QML type registration is process-global, while tests need a fresh facade per
    engine. Only two well-named singletons exist, so this stays far from the
    "many implicit globals" the architecture plan warns about. The packaging ticket
    (F6) will move to a qmldir-backed typed registration for the single-process app.
    """
    facade = facade if facade is not None else MockNovelStudioFacade()
    theme = theme if theme is not None else ThemeProvider()
    engine.rootContext().setContextProperty("Facade", facade)
    engine.rootContext().setContextProperty("Theme", theme)
    engine.rootContext().setContextProperty("WritingPageUseWebEngine", False)
    return facade, theme


def app_qml_path() -> Path:
    return Path(__file__).resolve().parent / "qml" / "App.qml"


def visual_lab_qml_path() -> Path:
    """Standalone Visual V0 sample page (ideal-UI spec 15, stage V0)."""
    return Path(__file__).resolve().parent / "qml" / "VisualLab.qml"


def create_engine() -> QQmlApplicationEngine:
    """Build the TextArea-mode shell (tests and screenshot baseline)."""
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(Path(__file__).resolve().parent / "qml"))
    facade, theme = register_frontend_types(engine)
    # Keep Python-side references alive for the engine's lifetime; otherwise the
    # QObject wrappers can be garbage collected and QML sees null singletons.
    _FRONTEND_STATE[id(engine)] = (facade, theme)
    engine.load(QUrl.fromLocalFile(str(app_qml_path())))
    return engine


def main(argv: Sequence[str] | None = None) -> int:
    args = list(argv) if argv is not None else sys.argv
    use_webengine = "--textarea" not in args
    args = [arg for arg in args if arg != "--textarea"]
    visual_lab = "--visual-lab" in args
    args = [arg for arg in args if arg != "--visual-lab"]
    if use_webengine and not visual_lab:
        # QtWebEngine's GPU compositor on Windows can lose its D3D context
        # during layout-driven resizes (AI dock open/close), leaving a black
        # strip in the newly exposed editor area until the renderer recovers.
        # Software compositing is stable for this text-only page and removes
        # the artifact; the user can override via their own Chromium flags.
        os.environ.setdefault("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-gpu")
        from PySide6.QtWebEngineQuick import QtWebEngineQuick

        ensure_editor_dist()
        ensure_qwebchannel_js()
        QtWebEngineQuick.initialize()

    app = QGuiApplication(args)
    app.setApplicationName("AI Novel Studio (QML F1)")
    app.setOrganizationName("AI Novel Studio")
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(Path(__file__).resolve().parent / "qml"))
    facade, theme = register_frontend_types(engine)
    if visual_lab:
        # Basic style so custom `background` items on TextField (VisualLab and
        # FormCard) actually apply instead of being ignored by the native style.
        os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
        # Visual V0 sample page: no WebEngine, no editor bridge. It is a
        # standalone experiment surface, not the production shell.
        _FRONTEND_STATE[id(engine)] = (facade, theme)
        engine.load(QUrl.fromLocalFile(str(visual_lab_qml_path())))
        if not engine.rootObjects():
            return 1
        return app.exec()
    engine.rootContext().setContextProperty("WritingPageUseWebEngine", use_webengine)
    if use_webengine:
        from ai_novel_studio.ui_qml.bridge.editor_bridge import EditorBridge

        editor_bridge = EditorBridge(engine)
        editor_bridge.save_requested.connect(
            lambda chapter_id, revision, markdown, content_hash: facade.saveFromEditor(
                chapter_id, revision, markdown
            )
        )
        editor_bridge.error.connect(facade.setSaveStatusText)
        editor_bridge.word_count_changed.connect(facade.setWebEngineWordCount)
        editor_bridge.selection_reference_changed.connect(
            facade.setSelectionReferenceJson
        )
        engine.rootContext().setContextProperty("pythonBridge", editor_bridge)
        dist = ensure_editor_dist()
        engine.rootContext().setContextProperty(
            "EditorAssets",
            EditorAssets((dist / "index.html").as_uri(), engine),
        )
    _FRONTEND_STATE[id(engine)] = (facade, theme)
    engine.load(QUrl.fromLocalFile(str(app_qml_path())))
    if not engine.rootObjects():
        return 1
    return app.exec()
