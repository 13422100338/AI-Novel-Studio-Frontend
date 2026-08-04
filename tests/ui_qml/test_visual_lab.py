"""Visual V0 sample page (ideal-UI spec 15): surfaces, tiers, quality, glow."""

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


def test_visual_lab_loads_all_demo_surfaces(qtbot: QtBot) -> None:
    _, _, _, window = _load_lab(qtbot)

    assert window.objectName() == "visualLabWindow"
    content = _content(window)
    for name in (
        "labBackgroundLayer",
        "labAcrylicSurface",
        "labGlassSurface",
        "labGlassCompare",
        "labAcrylicCompare",
        "labMicaCompare",
        "labFlatCompare",
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
        "labReduceMotionButton",
        "labGlowThinking",
        "labGlowSuccess",
        "labGlowError",
        "labGlowCancelled",
        "labTheme-paper",
        "labTheme-dark",
        "labQuality-safe",
        "labQuality-balanced",
        "labQuality-premium",
    ):
        item = _find_item(content, name)
        assert item is not None, f"missing {name}"


def test_visual_lab_theme_switch_updates_window(qtbot: QtBot) -> None:
    _, _, theme, window = _load_lab(qtbot)

    assert theme.property("themeName") == "paper"
    theme.setTheme("dark")
    tokens = theme.property("tokens")
    assert tokens["color"]["bgCanvas"] == "#202124"


def test_visual_quality_degrades_acrylic_to_opaque_and_disables_blur(
    qtbot: QtBot,
) -> None:
    _, _, theme, window = _load_lab(qtbot)
    acrylic = _find_item(_content(window), "labAcrylicSurface")
    assert acrylic is not None

    assert theme.property("visualQuality") == "balanced"
    assert acrylic.property("blurEnabled") is True
    assert acrylic.property("effectActive") is True
    # Acrylic tint: #FBF8F0 at glassTintOpacity 0.62 -> alpha ~0x9E.
    _assert_color_approx(acrylic.property("fillColor"), "#9EFBF8F0")

    theme.setVisualQuality("safe")
    qtbot.waitUntil(lambda: acrylic.property("blurEnabled") is False)
    assert acrylic.property("effectActive") is False
    # Safe tier degrades to a fully opaque surface color.
    assert _qcolor(acrylic.property("fillColor")).name() == "#fbf8f0"

    theme.setVisualQuality("premium")
    qtbot.waitUntil(lambda: acrylic.property("blurEnabled") is True)
    assert acrylic.property("effectActive") is True
    _assert_color_approx(acrylic.property("fillColor"), "#9EFBF8F0")


def test_acrylic_captures_background_layer(qtbot: QtBot) -> None:
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    acrylic = _find_item(content, "labAcrylicSurface")
    background = _find_item(content, "labBackgroundLayer")
    assert acrylic is not None and background is not None

    source = acrylic.property("sourceItem")
    assert source is not None
    assert source.objectName() == "labBackgroundLayer"

    # The capture rectangle follows the panel geometry inside the layer.
    rect = acrylic.property("captureRect")
    assert rect is not None
    assert rect.width() > 100
    assert rect.height() > 100
    assert abs(rect.width() - float(acrylic.property("width"))) < 1
    assert abs(rect.height() - float(acrylic.property("height"))) < 1


def test_system_backdrop_mode_switches_to_opaque_glass(qtbot: QtBot) -> None:
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    acrylic = _find_item(content, "labAcrylicSurface")
    glass = _find_item(content, "labGlassSurface")
    mica_compare = _find_item(content, "labMicaCompare")
    assert acrylic is not None and glass is not None and mica_compare is not None

    # Default (no system backdrop): real-time Acrylic visible, glass hidden.
    assert acrylic.property("visible") is True
    assert glass.property("visible") is False

    window.setProperty("systemBackdrop", True)
    qtbot.waitUntil(lambda: glass.property("visible") is True)
    assert acrylic.property("visible") is False
    assert glass.property("opaque") is True
    assert mica_compare.property("visible") is True

    # Backdrop mode makes the window transparent so DWM draws behind it.
    color = window.property("color")
    assert color.alpha() == 0

    window.setProperty("systemBackdrop", False)
    qtbot.waitUntil(lambda: acrylic.property("visible") is True)
    assert glass.property("visible") is False
    assert window.property("color").alpha() == 255


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


def test_visual_quality_segment_buttons_switch_quality(qtbot: QtBot) -> None:
    _, _, theme, window = _load_lab(qtbot)
    content = _content(window)

    premium = _find_item(content, "labQuality-premium")
    assert premium is not None
    QMetaObject.invokeMethod(premium, "clicked")
    qtbot.waitUntil(lambda: theme.property("visualQuality") == "premium")

    safe = _find_item(content, "labQuality-safe")
    assert safe is not None
    QMetaObject.invokeMethod(safe, "clicked")
    qtbot.waitUntil(lambda: theme.property("visualQuality") == "safe")

    dark = _find_item(content, "labTheme-dark")
    assert dark is not None
    QMetaObject.invokeMethod(dark, "clicked")
    qtbot.waitUntil(lambda: theme.property("themeName") == "dark")


def test_glow_state_buttons_pin_success_error_cancelled(qtbot: QtBot) -> None:
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    glow = _find_item(content, "labStreamingGlow")
    assert glow is not None

    # Thinking: drift animation is live (blue-violet A/B).
    assert glow.property("animationRunning") is True

    success = _find_item(content, "labGlowSuccess")
    assert success is not None
    QMetaObject.invokeMethod(success, "clicked")
    qtbot.waitUntil(lambda: glow.property("frameColor") == "#3E7C4F")
    assert glow.property("animationRunning") is False

    error = _find_item(content, "labGlowError")
    assert error is not None
    QMetaObject.invokeMethod(error, "clicked")
    qtbot.waitUntil(lambda: glow.property("frameColor") == "#A6453F")

    cancelled = _find_item(content, "labGlowCancelled")
    assert cancelled is not None
    QMetaObject.invokeMethod(cancelled, "clicked")
    qtbot.waitUntil(lambda: glow.property("frameColor") == "#9A958C")

    thinking = _find_item(content, "labGlowThinking")
    assert thinking is not None
    QMetaObject.invokeMethod(thinking, "clicked")
    qtbot.waitUntil(lambda: glow.property("animationRunning") is True)


def test_reduce_motion_button_toggles_glow_to_static(qtbot: QtBot) -> None:
    _, facade, _, window = _load_lab(qtbot)
    content = _content(window)
    glow = _find_item(content, "labStreamingGlow")
    toggle = _find_item(content, "labReduceMotionButton")
    assert glow is not None and toggle is not None

    assert facade.property("reduceMotion") is False
    assert glow.property("animationRunning") is True

    QMetaObject.invokeMethod(toggle, "clicked")
    qtbot.waitUntil(lambda: facade.property("reduceMotion") is True)
    qtbot.waitUntil(lambda: glow.property("animationRunning") is False)
    assert glow.property("frameColor") == "#7C6FD8"  # static thinkingA

    QMetaObject.invokeMethod(toggle, "clicked")
    qtbot.waitUntil(lambda: facade.property("reduceMotion") is False)
    qtbot.waitUntil(lambda: glow.property("animationRunning") is True)
