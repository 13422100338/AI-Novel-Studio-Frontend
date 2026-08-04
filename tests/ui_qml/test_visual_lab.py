"""Visual V0 sample page (ideal-UI spec 15): surfaces, tiers, quality, glow."""

from pathlib import Path

import pytest
from PySide6.QtCore import QUrl
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem, QQuickWindow
from pytestqt.qtbot import QtBot

from ai_novel_studio.ui_qml.bootstrap import (
    register_frontend_types,
    visual_lab_qml_path,
)
from ai_novel_studio.ui_qml.bridge.mock_novel_studio_facade import MockNovelStudioFacade
from ai_novel_studio.ui_qml.bridge.theme_provider import ThemeProvider

_ACTIVE_ENGINES: list[QQmlApplicationEngine] = []


@pytest.fixture(autouse=True)
def _delete_active_engines() -> None:
    yield
    for engine in _ACTIVE_ENGINES:
        engine.deleteLater()
    _ACTIVE_ENGINES.clear()


def _find_item(root: QQuickItem, name: str) -> QQuickItem | None:
    if root.objectName() == name:
        return root
    for child in root.childItems():
        found = _find_item(child, name)
        if found is not None:
            return found
    return None


def _load_lab(
    qtbot: QtBot,
) -> tuple[QQmlApplicationEngine, MockNovelStudioFacade, ThemeProvider, QQuickWindow]:
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(Path(visual_lab_qml_path()).parent))
    facade = MockNovelStudioFacade()
    theme = ThemeProvider()
    register_frontend_types(engine, facade, theme)
    engine.load(QUrl.fromLocalFile(str(visual_lab_qml_path())))
    assert engine.rootObjects(), "VisualLab.qml failed to load"
    window = engine.rootObjects()[0]
    assert isinstance(window, QQuickWindow)
    _ACTIVE_ENGINES.append(engine)
    return engine, facade, theme, window


def _content(window: QQuickWindow) -> QQuickItem:
    content = window.contentItem()
    assert isinstance(content, QQuickItem)
    return content


def test_visual_lab_loads_all_demo_surfaces(qtbot: QtBot) -> None:
    _, _, _, window = _load_lab(qtbot)

    assert window.objectName() == "visualLabWindow"
    content = _content(window)
    for name in (
        "labGlassSurface",
        "labPaperSurface",
        "labElevatedSurface",
        "labPrimaryButton",
        "labSecondaryButton",
        "labGhostButton",
        "labInputField",
        "labDiffCard",
        "labChangeSetCard",
        "labFormCard",
        "labStreamingGlow",
        "labStaticGlow",
    ):
        item = _find_item(content, name)
        assert item is not None, f"missing {name}"


def test_visual_lab_theme_switch_updates_window(qtbot: QtBot) -> None:
    _, _, theme, window = _load_lab(qtbot)

    assert theme.property("themeName") == "paper"
    theme.setTheme("dark")
    tokens = theme.property("tokens")
    assert tokens["color"]["bgCanvas"] == "#202124"


def test_visual_quality_degrades_glass_to_opaque(qtbot: QtBot) -> None:
    _, _, theme, window = _load_lab(qtbot)
    glass = _find_item(_content(window), "labGlassSurface")
    assert glass is not None

    assert theme.property("visualQuality") == "balanced"
    assert glass.property("fillColor") == "#CFFBF8F0"

    theme.setVisualQuality("safe")
    qtbot.waitUntil(lambda: glass.property("fillColor") == "#FBF8F0")

    theme.setVisualQuality("premium")
    qtbot.waitUntil(lambda: glass.property("fillColor") == "#CFFBF8F0")


def test_streaming_glow_degrades_with_reduce_motion(qtbot: QtBot) -> None:
    _, facade, _, window = _load_lab(qtbot)
    glow = _find_item(_content(window), "labStreamingGlow")
    assert glow is not None

    assert glow.property("animationRunning") is True
    facade.setReduceMotion(True)
    qtbot.waitUntil(lambda: glow.property("animationRunning") is False)
    assert glow.property("frameColor") == "#7C6FD8"  # static thinkingA


def test_visual_quality_cycles_safe_balanced_premium(qtbot: QtBot) -> None:
    _, _, theme, _ = _load_lab(qtbot)

    assert theme.nextVisualQuality() == "premium"
    theme.setVisualQuality("premium")
    assert theme.property("visualQuality") == "premium"
    assert theme.nextVisualQuality() == "safe"
    theme.setVisualQuality("unknown")
    # Invalid quality values fall back to the Balanced default.
    assert theme.property("visualQuality") == "balanced"
