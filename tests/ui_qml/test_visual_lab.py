"""Visual V0 rework (diagnosis doc): four-column workspace, app acrylic."""

from pathlib import Path

import pytest
from PySide6.QtCore import QMetaObject, QObject, QUrl, Slot
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


class _BackdropStub(QObject):
    """Test stub: DWM system backdrop always unavailable (safe fallback)."""

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.calls: list[str] = []

    @Slot(str, result=bool)
    def apply(self, kind: str) -> bool:
        self.calls.append(kind)
        return False


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
    engine.rootContext().setContextProperty("BackdropBridge", _BackdropStub())
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
        "labSliderTemplateButton",
        "sliderTemplateDock",
        "glassSliderPrimary",
        "glassSliderSteps",
        "glassSliderDisabled",
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
    # Acrylic tint: #FBF8F0 at glassTintBalanced 0.78 -> alpha ~0xC7.
    _assert_color_approx(acrylic.property("fillColor"), "#C7FBF8F0")

    theme.setVisualQuality("safe")
    qtbot.waitUntil(lambda: acrylic.property("blurEnabled") is False)
    assert acrylic.property("effectActive") is False
    assert _qcolor(acrylic.property("fillColor")).name() == "#fbf8f0"

    theme.setVisualQuality("premium")
    qtbot.waitUntil(lambda: acrylic.property("blurEnabled") is True)
    assert acrylic.property("effectActive") is True
    # Premium uses a much thinner tint (0.42 -> alpha ~0x6B) + stronger blur.
    _assert_color_approx(acrylic.property("fillColor"), "#6BFBF8F0")
    assert float(acrylic.property("blurMax")) == 56


def test_quality_tiers_change_nav_sidebar_and_ai_glass(qtbot: QtBot) -> None:
    """All three glass columns (nav, sidebar, AI) must respond to tiers."""
    _, _, theme, window = _load_lab(qtbot)
    content = _content(window)
    nav = _find_item(content, "labNavRail")
    sidebar = _find_item(content, "labChapterSidebar")
    acrylic = _find_item(content, "labAcrylicSurface")
    assert nav is not None and sidebar is not None and acrylic is not None

    # Balanced: blur on for all three.
    assert theme.property("visualQuality") == "balanced"
    for item in (nav, sidebar, acrylic):
        assert item.property("blurEnabled") is True, item.objectName()

    # Safe: blur off and opaque fill for all three.
    theme.setVisualQuality("safe")
    qtbot.waitUntil(lambda: nav.property("blurEnabled") is False)
    for item in (nav, sidebar, acrylic):
        assert item.property("blurEnabled") is False, item.objectName()
        assert _qcolor(item.property("fillColor")).name() == "#fbf8f0"

    # Premium: blur on again.
    theme.setVisualQuality("premium")
    qtbot.waitUntil(lambda: nav.property("blurEnabled") is True)
    for item in (nav, sidebar, acrylic):
        assert item.property("blurEnabled") is True, item.objectName()


def test_liquid_glass_layers_follow_quality_tiers(qtbot: QtBot) -> None:
    """Edge light/inner shadow layers are hidden in Safe, active in Balanced,
    and stronger in Premium (the specular sheen was removed per feedback)."""
    _, _, theme, window = _load_lab(qtbot)
    content = _content(window)
    acrylic = _find_item(content, "labAcrylicSurface")
    liquid_lights = _find_item(content, "liquidLights")
    assert acrylic is not None
    assert liquid_lights is not None

    # Balanced: liquid layers active with positive strength.
    assert theme.property("visualQuality") == "balanced"
    assert float(acrylic.property("edgeLightOpacity")) > 0
    assert float(acrylic.property("innerShadowOpacity")) > 0
    assert liquid_lights.property("visible") is True

    # Safe: all liquid layers hidden and strengths zero.
    theme.setVisualQuality("safe")
    qtbot.waitUntil(lambda: float(acrylic.property("edgeLightOpacity")) == 0.0)
    assert float(acrylic.property("edgeLightOpacity")) == 0.0
    assert float(acrylic.property("innerShadowOpacity")) == 0.0
    assert liquid_lights.property("visible") is False

    # Premium: strictly stronger than Balanced (tier separation must hold).
    theme.setVisualQuality("balanced")
    qtbot.wait(30)
    balanced_edge = float(acrylic.property("edgeLightOpacity"))
    balanced_shadow = float(acrylic.property("innerShadowOpacity"))
    theme.setVisualQuality("premium")
    qtbot.waitUntil(
        lambda: float(acrylic.property("edgeLightOpacity")) > balanced_edge
    )
    assert float(acrylic.property("innerShadowOpacity")) > balanced_shadow
    assert liquid_lights.property("visible") is True


def test_four_main_panels_share_unified_edge_material(qtbot: QtBot) -> None:
    """Nav rail, chapter sidebar, central editor and AI panel share the same
    flat edge treatment: no per-panel drop-shadow switch left in the shared
    surface (user feedback: edges must be unified) and identical LiquidLights
    layer. The central editor also blurs the same BackdropLayer glow."""
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    acrylic = _find_item(content, "labAcrylicSurface")
    nav = _find_item(content, "labNavRail")
    sidebar = _find_item(content, "labChapterSidebar")
    editor = _find_item(content, "labPaperSurface")
    background = _find_item(content, "labBackgroundLayer")
    assert acrylic is not None and nav is not None and sidebar is not None
    assert editor is not None and background is not None

    for item in (nav, sidebar, editor, acrylic):
        # The drop-shadow toggle was removed from the shared surface: every
        # panel is flat and none can carry a shadow while others do not.
        assert item.property("elevated") is None, item.objectName()
        lights = _find_item(item, "liquidLights")
        assert lights is not None, f"{item.objectName()}: liquidLights missing"
        assert lights.property("visible") is True
        assert lights.property("radius") == item.property("radius")
        assert abs(
            float(lights.property("edgeLightOpacity"))
            - float(acrylic.property("edgeLightOpacity"))
        ) < 1e-6, f"{item.objectName()}: edge light must match AI panel"
        assert abs(
            float(lights.property("innerShadowOpacity"))
            - float(acrylic.property("innerShadowOpacity"))
        ) < 1e-6, f"{item.objectName()}: inner shadow must match AI panel"

    # The central editor is glass now, not the opaque paper surface: it must
    # capture the same backdrop layer as the AI panel.
    assert editor.property("sourceItem") is not None
    assert editor.property("sourceItem").objectName() == "labBackgroundLayer"


def test_header_joins_unified_glass_material(qtbot: QtBot) -> None:
    """The app header is an Acrylic surface over the same backdrop, with the
    same edge light/inner shadow language as the four-column workspace."""
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    header = _find_item(content, "labHeader")
    acrylic = _find_item(content, "labAcrylicSurface")
    background = _find_item(content, "labBackgroundLayer")
    assert header is not None and acrylic is not None and background is not None

    assert header.property("elevated") is None
    assert header.property("sourceItem").objectName() == "labBackgroundLayer"
    lights = _find_item(header, "liquidLights")
    assert lights is not None
    assert abs(
        float(lights.property("edgeLightOpacity"))
        - float(acrylic.property("edgeLightOpacity"))
    ) < 1e-6
    assert abs(
        float(lights.property("innerShadowOpacity"))
        - float(acrylic.property("innerShadowOpacity"))
    ) < 1e-6


def test_acrylic_capture_turns_off_when_hidden_or_safe(qtbot: QtBot) -> None:
    """Performance gate (glass-UI doc §12.1): the ShaderEffectSource must stop
    rendering when a panel is hidden or the quality drops to Safe."""
    _, _, theme, window = _load_lab(qtbot)
    content = _content(window)
    acrylic = _find_item(content, "labAcrylicSurface")
    assert acrylic is not None
    capture = _find_item(acrylic, "acrylicCapture")
    assert capture is not None

    # Balanced + visible: capture runs.
    assert theme.property("visualQuality") == "balanced"
    assert capture.property("enabled") is True

    # Safe: capture off.
    theme.setVisualQuality("safe")
    qtbot.waitUntil(lambda: capture.property("enabled") is False)

    # Back to balanced; hiding the panel also turns the capture off.
    theme.setVisualQuality("balanced")
    qtbot.waitUntil(lambda: capture.property("enabled") is True)
    acrylic.setProperty("visible", False)
    qtbot.waitUntil(lambda: capture.property("enabled") is False)


def test_resize_keeps_capture_rect_in_sync(qtbot: QtBot) -> None:
    """Glass-UI doc §13: resizing the window must keep every Acrylic capture
    rect glued to its panel geometry (no smeared or offset blur)."""
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    acrylic = _find_item(content, "labAcrylicSurface")
    nav = _find_item(content, "labNavRail")
    assert acrylic is not None and nav is not None

    for item in (nav, acrylic):
        rect = item.property("captureRect")
        assert abs(rect.width() - float(item.property("width"))) < 2
        assert abs(rect.height() - float(item.property("height"))) < 2

    window.resize(1100, 700)
    qtbot.wait(80)

    for item in (nav, acrylic):
        rect = item.property("captureRect")
        assert abs(rect.width() - float(item.property("width"))) < 2, (
            f"{item.objectName()}: capture width out of sync after resize"
        )
        assert abs(rect.height() - float(item.property("height"))) < 2, (
            f"{item.objectName()}: capture height out of sync after resize"
        )


def test_agent_cards_share_liquid_edge_lights(qtbot: QtBot) -> None:
    """Cards (TextDiff/ChangeSet/Form) share the edge light + inner shadow
    language of the glass panels; Safe hides it entirely."""
    _, _, theme, window = _load_lab(qtbot)
    content = _content(window)
    for card_name in ("labDiffCard", "labChangeSetCard", "labFormCard"):
        card = _find_item(content, card_name)
        assert card is not None, f"missing {card_name}"
        lights = _find_item(card, "cardLiquidLights")
        assert lights is not None, f"{card_name}: cardLiquidLights missing"
        assert lights.property("visible") is True
        assert float(lights.property("edgeLightOpacity")) > 0
        assert float(lights.property("innerShadowOpacity")) > 0

    theme.setVisualQuality("safe")
    card = _find_item(content, "labDiffCard")
    lights = _find_item(card, "cardLiquidLights")
    qtbot.waitUntil(lambda: lights.property("visible") is False)


def test_light_theme_glass_uses_positive_saturation(qtbot: QtBot) -> None:
    """Regression: light theme previously used negative saturation, which
    washed the glass out; iOS-style vibrancy needs a positive boost."""
    _, _, theme, window = _load_lab(qtbot)
    acrylic = _find_item(_content(window), "labAcrylicSurface")
    assert acrylic is not None
    theme.setTheme("light")
    assert float(acrylic.property("saturation")) > 0
    theme.setTheme("dark")
    assert float(acrylic.property("saturation")) > 0


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


def test_theme_switch_produces_no_black_blocks(qtbot: QtBot) -> None:
    """Diagnosis doc 13.5: switching themes must not create black holes."""
    _, _, theme, window = _load_lab(qtbot)
    for name in ("paper", "light", "dark"):
        theme.setTheme(name)
        qtbot.wait(40)
        image = _grab(window)
        W, H = image.width(), image.height()
        dark = 0
        for y in range(0, H, 8):
            for x in range(0, W, 8):
                c = image.pixelColor(x, y)
                if max(c.red(), c.green(), c.blue()) < 12:
                    dark += 1
        assert dark == 0, f"pure-black pixels at theme {name}"


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


def test_experiment_panel_shares_unified_edge_lights(qtbot: QtBot) -> None:
    """The experiment control strip carries the same faint edge light + inner
    shadow as cards so every container shares the material language."""
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    open_button = _find_item(content, "experimentOpenButton")
    panel = _find_item(content, "experimentControlPanel")
    assert open_button is not None and panel is not None

    QMetaObject.invokeMethod(open_button, "clicked")
    qtbot.waitUntil(lambda: panel.property("open") is True)

    lights = _find_item(panel, "controlPanelLiquidLights")
    assert lights is not None
    assert lights.property("visible") is True
    assert float(lights.property("edgeLightOpacity")) > 0
    assert float(lights.property("innerShadowOpacity")) > 0


def test_experiment_panel_never_covers_ai_panel(qtbot: QtBot) -> None:
    """Regression: the control strip must not overlap the AI assistant panel."""
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    open_button = _find_item(content, "experimentOpenButton")
    panel = _find_item(content, "experimentControlPanel")
    ai = _find_item(content, "labAcrylicSurface")
    assert open_button is not None and panel is not None and ai is not None

    # Map both items into the window-content coordinate system.
    ai_origin = ai.mapToItem(content, 0, 0)
    ai_rect = (
        ai_origin.x(),
        ai_origin.y(),
        ai_origin.x() + ai.width(),
        ai_origin.y() + ai.height(),
    )

    QMetaObject.invokeMethod(open_button, "clicked")
    qtbot.waitUntil(lambda: panel.property("open") is True)
    qtbot.wait(60)

    # After opening, both the strip and the AI panel are laid out; re-map both.
    ai_origin2 = ai.mapToItem(content, 0, 0)
    ai_rect = (
        ai_origin2.x(),
        ai_origin2.y(),
        ai_origin2.x() + ai.width(),
        ai_origin2.y() + ai.height(),
    )
    panel_origin2 = panel.mapToItem(content, 0, 0)
    panel_rect = (
        panel_origin2.x(),
        panel_origin2.y(),
        panel_origin2.x() + panel.width(),
        panel_origin2.y() + panel.height(),
    )
    overlap_x = max(0, min(ai_rect[2], panel_rect[2]) - max(ai_rect[0], panel_rect[0]))
    overlap_y = max(0, min(ai_rect[3], panel_rect[3]) - max(ai_rect[1], panel_rect[1]))
    assert overlap_x * overlap_y == 0, (
        f"control panel overlaps AI panel: ai={ai_rect} panel={panel_rect}"
    )


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


def test_mica_failure_keeps_window_opaque(qtbot: QtBot) -> None:
    """When DWM rejects the backdrop, the window must stay opaque."""
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    open_button = _find_item(content, "experimentOpenButton")
    mica_toggle = _find_item(content, "labMicaToggle")
    assert open_button is not None and mica_toggle is not None

    QMetaObject.invokeMethod(open_button, "clicked")
    qtbot.waitUntil(
        lambda: _find_item(content, "experimentControlPanel").property("open") is True
    )
    QMetaObject.invokeMethod(mica_toggle, "clicked")
    qtbot.wait(60)

    # The stub returns False: window must remain opaque and backdrop off.
    assert window.property("systemBackdrop") is False
    assert window.property("micaActive") is False
    assert _qcolor(window.property("color")).alpha() == 255


def test_debug_overlay_toggles_propagate_to_window(qtbot: QtBot) -> None:
    """Experiment strip toggles must actually drive the window's overlays."""
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    open_button = _find_item(content, "experimentOpenButton")
    backdrop_toggle = _find_item(content, "labDebugBackdropToggle")
    source_toggle = _find_item(content, "labDebugSourceRectToggle")
    blur_toggle = _find_item(content, "labDebugBlurRegionToggle")
    assert open_button is not None
    assert backdrop_toggle is not None and source_toggle is not None
    assert blur_toggle is not None

    QMetaObject.invokeMethod(open_button, "clicked")
    qtbot.waitUntil(
        lambda: _find_item(content, "experimentControlPanel").property("open") is True
    )

    assert window.property("debugBackdrop") is False
    QMetaObject.invokeMethod(backdrop_toggle, "clicked")
    qtbot.waitUntil(lambda: window.property("debugBackdrop") is True)

    assert window.property("debugSourceRect") is False
    QMetaObject.invokeMethod(source_toggle, "clicked")
    qtbot.waitUntil(lambda: window.property("debugSourceRect") is True)

    assert window.property("debugBlurRegion") is False
    QMetaObject.invokeMethod(blur_toggle, "clicked")
    qtbot.waitUntil(lambda: window.property("debugBlurRegion") is True)


def _open_slider_dock(window: QQuickWindow) -> None:
    button = _find_item(window.contentItem(), "labSliderTemplateButton")
    assert button is not None
    QMetaObject.invokeMethod(button, "clicked")


def test_slider_template_dock_opens_and_closes(qtbot: QtBot) -> None:
    """The slider showcase folds up from the bottom like the experiment strip
    and never needs to cover the workspace."""
    _, _, _, window = _load_lab(qtbot)
    content = _content(window)
    dock = _find_item(content, "sliderTemplateDock")
    close_button = _find_item(content, "sliderTemplateCloseButton")
    assert dock is not None and close_button is not None
    assert dock.property("visible") is False

    _open_slider_dock(window)
    qtbot.waitUntil(lambda: dock.property("visible") is True)
    qtbot.wait(60)

    QMetaObject.invokeMethod(close_button, "clicked")
    qtbot.waitUntil(lambda: dock.property("visible") is False)


def test_glass_slider_value_mapping_steps_and_clamp(qtbot: QtBot) -> None:
    """The GlassSlider maps value to thumb 1:1, clamps out-of-range input and
    snaps to step through one validation path (property guard)."""
    _, facade, _, window = _load_lab(qtbot)
    # Deterministic geometry: disable springs first, then check the 1:1 map.
    facade.setReduceMotion(True)
    _open_slider_dock(window)
    qtbot.wait(80)
    primary = _find_item(_content(window), "glassSliderPrimary")
    steps = _find_item(_content(window), "glassSliderSteps")
    assert primary is not None and steps is not None

    # 42 of 0..100 -> normalized 0.42 and thumb centered there.
    primary.setProperty("value", 42.0)
    qtbot.wait(20)
    assert abs(float(primary.property("normalized")) - 0.42) < 0.001
    expected = (
        float(primary.property("trackLeft"))
        + 0.42 * float(primary.property("trackWidth"))
    )
    assert abs(float(primary.property("thumbCenterX")) - expected) < 0.5

    # Out-of-range clamps to 100 (normalized 1.0).
    primary.setProperty("value", 500.0)
    qtbot.wait(20)
    assert abs(float(primary.property("normalized")) - 1.0) < 0.001

    # Step slider snaps 2150 -> 2200 (step 100), stays inside 800..4000.
    steps.setProperty("value", 2150.0)
    qtbot.wait(20)
    assert abs(float(steps.property("value")) - 2200.0) < 0.001


def test_glass_slider_disabled_and_safe_stay_functional(qtbot: QtBot) -> None:
    """Disabled sliders refuse interaction but keep valid values; Safe tier
    strips visuals without breaking functionality (glass-UI doc §12.3)."""
    _, _, theme, window = _load_lab(qtbot)
    _open_slider_dock(window)
    qtbot.wait(80)
    disabled = _find_item(_content(window), "glassSliderDisabled")
    primary = _find_item(_content(window), "glassSliderPrimary")
    assert disabled is not None and primary is not None

    assert disabled.property("interactive") is False
    assert abs(float(disabled.property("value")) - 60.0) < 0.001

    theme.setVisualQuality("safe")
    qtbot.wait(40)
    primary.setProperty("value", 30.0)
    qtbot.wait(20)
    assert abs(float(primary.property("normalized")) - 0.30) < 0.001


def test_glass_slider_respects_reduce_motion(qtbot: QtBot) -> None:
    """Facade.reduceMotion disables the spring/behavior layer so the slider
    stays crisp and static (apple-design §14)."""
    _, facade, _, window = _load_lab(qtbot)
    _open_slider_dock(window)
    qtbot.wait(80)
    primary = _find_item(_content(window), "glassSliderPrimary")
    assert primary is not None

    assert primary.property("springEnabled") is True
    facade.setReduceMotion(True)
    qtbot.waitUntil(lambda: primary.property("springEnabled") is False)


def test_slider_dock_shares_unified_edge_lights(qtbot: QtBot) -> None:
    """The showcase dock carries the same faint edge light + inner shadow as
    cards so every container keeps the shared material language."""
    _, _, _, window = _load_lab(qtbot)
    _open_slider_dock(window)
    qtbot.wait(80)
    dock = _find_item(_content(window), "sliderTemplateDock")
    assert dock is not None
    lights = _find_item(dock, "sliderDockLiquidLights")
    assert lights is not None
    assert lights.property("visible") is True
    assert float(lights.property("edgeLightOpacity")) > 0
    assert float(lights.property("innerShadowOpacity")) > 0


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
