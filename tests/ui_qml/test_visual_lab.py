"""Visual V0 rework (diagnosis doc): four-column workspace, app acrylic."""

from pathlib import Path

import pytest
from PySide6.QtCore import QMetaObject, QUrl
from PySide6.QtGui import QColor
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
    window.resize(1440, 900)
    window.show()
    _ACTIVE_ENGINES.append(engine)
    return engine, facade, theme, window


def _content(window: QQuickWindow) -> QQuickItem:
    content = window.contentItem()
    assert isinstance(content, QQuickItem)
    return content


def _qcolor(value: object) -> QColor:
    if isinstance(value, QColor):
        return value
    return QColor(str(value))


def _assert_color_approx(actual: object, expected_hex: str, tolerance: int = 2) -> None:
    actual_color = _qcolor(actual)
    expected = QColor(expected_hex)
    for channel in ("red", "green", "blue", "alpha"):
        assert (
            abs(getattr(actual_color, channel)() - getattr(expected, channel)())
            <= tolerance
        ), f"{channel} mismatch: {actual_color.name()} vs {expected_hex}"


def _grab(window: QQuickWindow) -> object:
    for _ in range(6):
        window.contentItem().update()
    image = window.grabWindow()
    assert not image.isNull()
    return image


def test_visual_lab_loads_four_column_workspace(qtbot: QtBot) -> None:
    """The rework mirrors the target workspace: nav, sidebar, paper, AI."""
    _, _, _, window = _load_lab(qtbot)

    assert window.objectName() == "visualLabWindow"
    content = _content(window)
    for name in (
        "labBackgroundLayer",
        "labAcrylicSurface",
        "labGlassSurface",
        "labPaperSurface",
        "labChapterList",
        "labDiffCard",
        "labChangeSetCard",
        "labFormCard",
        "labStreamingGlow",
        "labInputField",
        "experimentOpenButton",
        "experimentControlPanel",
        "experimentCloseButton",
        "labMicaToggle",
        "labDebugBackdropToggle",
        "labDebugSourceRectToggle",
        "labDebugBlurRegionToggle",
    ):
        item = _find_item(content, name)
        assert item is not None, f"missing {name}"


def test_backdrop_layer_covers_whole_window(qtbot: QtBot) -> None:
    """Diagnosis doc 13.1: BackdropLayer must cover the full window."""
    _, _, _, window = _load_lab(qtbot)
    backdrop = _find_item(_content(window), "labBackgroundLayer")
    assert backdrop is not None

    assert backdrop.x() == 0
    assert backdrop.y() == 0
    assert abs(backdrop.width() - float(window.width())) < 1
    assert abs(backdrop.height() - float(window.height())) < 1


def test_window_has_no_bare_black_regions(qtbot: QtBot) -> None:
    """Diagnosis doc 13.2/15: no visible black exposed areas."""
    _, _, _, window = _load_lab(qtbot)
    image = _grab(window)
    W, H = image.width(), image.height()

    dark = 0
    total = 0
    for y in range(0, H, 8):
        for x in range(0, W, 8):
            c = image.pixelColor(x, y)
            total += 1
            if max(c.red(), c.green(), c.blue()) < 12:
                dark += 1
    assert dark == 0, f"{dark}/{total} sampled pixels are pure black"


def test_main_panels_stay_inside_window(qtbot: QtBot) -> None:
    """Diagnosis doc 13.3: all main panels are inside the window bounds."""
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    w = float(window.width())
    h = float(window.height())

    for name in ("labAcrylicSurface", "labPaperSurface"):
        item = _find_item(content, name)
        assert item is not None
        assert item.x() >= 0
        assert item.y() >= 0
        assert item.x() + item.width() <= w + 1
        assert item.y() + item.height() <= h + 1


def test_acrylic_captures_backdrop_layer(qtbot: QtBot) -> None:
    """Diagnosis doc 13.4: sourceItem is the backdrop; sourceRect matches."""
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    acrylic = _find_item(content, "labAcrylicSurface")
    background = _find_item(content, "labBackgroundLayer")
    assert acrylic is not None and background is not None

    source = acrylic.property("sourceItem")
    assert source is not None
    assert source.objectName() == "labBackgroundLayer"

    rect = acrylic.property("captureRect")
    assert rect is not None
    assert rect.width() > 100
    assert rect.height() > 100
    assert abs(rect.width() - float(acrylic.property("width"))) < 2
    assert abs(rect.height() - float(acrylic.property("height"))) < 2


def test_visual_quality_degrades_acrylic_to_opaque_and_disables_blur(
    qtbot: QtBot,
) -> None:
    _, _, theme, window = _load_lab(qtbot)
    acrylic = _find_item(_content(window), "labAcrylicSurface")
    assert acrylic is not None

    assert theme.property("visualQuality") == "balanced"
    assert acrylic.property("blurEnabled") is True
    assert acrylic.property("effectActive") is True

    theme.setVisualQuality("safe")
    qtbot.waitUntil(lambda: acrylic.property("blurEnabled") is False)
    assert acrylic.property("effectActive") is False
    assert _qcolor(acrylic.property("fillColor")).name() == "#fbf8f0"

    theme.setVisualQuality("premium")
    qtbot.waitUntil(lambda: acrylic.property("blurEnabled") is True)
    assert acrylic.property("effectActive") is True


def test_quality_switch_keeps_layout_geometry(qtbot: QtBot) -> None:
    """Diagnosis doc 13.5: tier switches never change layout size."""
    _, _, theme, window = _load_lab(qtbot)
    content = _content(window)
    paper = _find_item(content, "labPaperSurface")
    acrylic = _find_item(content, "labAcrylicSurface")
    assert paper is not None and acrylic is not None

    baseline = (paper.x(), paper.y(), paper.width(), paper.height(),
                acrylic.x(), acrylic.y(), acrylic.width(), acrylic.height())
    for quality in ("safe", "balanced", "premium"):
        theme.setVisualQuality(quality)
        qtbot.wait(30)
        current = (paper.x(), paper.y(), paper.width(), paper.height(),
                   acrylic.x(), acrylic.y(), acrylic.width(), acrylic.height())
        assert current == baseline, f"layout changed at {quality}"


def test_quality_switch_produces_no_black_blocks(qtbot: QtBot) -> None:
    _, _, theme, window = _load_lab(qtbot)
    for quality in ("safe", "balanced", "premium"):
        theme.setVisualQuality(quality)
        qtbot.wait(40)
        image = _grab(window)
        W, H = image.width(), image.height()
        dark = 0
        for y in range(0, H, 8):
            for x in range(0, W, 8):
                c = image.pixelColor(x, y)
                if max(c.red(), c.green(), c.blue()) < 12:
                    dark += 1
        assert dark == 0, f"black pixels at {quality}"


def test_visual_lab_theme_switch_updates_window(qtbot: QtBot) -> None:
    _, _, theme, window = _load_lab(qtbot)
    assert theme.property("themeName") == "paper"
    theme.setTheme("dark")
    tokens = theme.property("tokens")
    assert tokens["color"]["bgCanvas"] == "#202124"


def test_experiment_panel_opens_and_closes(qtbot: QtBot) -> None:
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    open_button = _find_item(content, "experimentOpenButton")
    panel = _find_item(content, "experimentControlPanel")
    close_button = _find_item(content, "experimentCloseButton")
    assert open_button is not None and panel is not None and close_button is not None

    QMetaObject.invokeMethod(open_button, "clicked")
    qtbot.waitUntil(lambda: panel.property("open") is True)

    QMetaObject.invokeMethod(close_button, "clicked")
    qtbot.waitUntil(lambda: panel.property("open") is False)


def test_experiment_panel_controls_switch_theme_and_quality(qtbot: QtBot) -> None:
    _, _, theme, window = _load_lab(qtbot)
    content = _content(window)

    dark = _find_item(content, "labTheme-dark")
    premium = _find_item(content, "labQuality-premium")
    assert dark is not None and premium is not None

    QMetaObject.invokeMethod(dark, "clicked")
    qtbot.waitUntil(lambda: theme.property("themeName") == "dark")
    QMetaObject.invokeMethod(premium, "clicked")
    qtbot.waitUntil(lambda: theme.property("visualQuality") == "premium")


def test_mica_experiment_defaults_off(qtbot: QtBot) -> None:
    _, _, _, window = _load_lab(qtbot)
    assert window.property("systemBackdrop") is False
    assert window.property("micaActive") is False


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
    assert theme.property("visualQuality") == "balanced"
