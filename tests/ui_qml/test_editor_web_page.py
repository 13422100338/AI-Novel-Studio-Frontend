"""C1.5: static invariants preventing WebEngine black edge strips.

These tests read the editor page source and QML host wiring and assert the
contract that keeps QtWebEngine from painting the default black canvas:
explicit viewport sizing, no body overflow, theme-colored scrollbars, an
explicit WebEngineView background, and no animated AI-dock width changes in
WebEngine mode. The WebEngine itself cannot run offscreen, so the invariants
are verified at the source level here and exercised live by
scripts/verify_webengine_edges.py on a real display.
"""

from __future__ import annotations

from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2] / "src" / "ai_novel_studio" / "ui_qml"
_STYLE = _ROOT / "editor_web" / "src" / "style.css"
_EDITOR_TS = _ROOT / "editor_web" / "src" / "editor.ts"
_WEBVIEW_QML = _ROOT / "qml" / "components" / "NovelEditorView.qml"
_DOCK_QML = _ROOT / "qml" / "components" / "AgentDock.qml"
_APP_QML = _ROOT / "qml" / "App.qml"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_viewport_fills_and_paints_editor_background() -> None:
    css = _read(_STYLE)
    for selector in ("html,", "body"):
        assert selector in css
    for rule in ("width: 100%;", "height: 100%;", "margin: 0;", "padding: 0;"):
        assert rule in css, f"missing viewport rule {rule!r}"
    assert "background: var(--editor-bg, #fffdf7);" in css
    assert "overflow: hidden;" in css, "body must not render its own scrollbar"


def test_global_border_box_and_mount_sizing() -> None:
    css = _read(_STYLE)
    assert "box-sizing: border-box;" in css
    assert "#editor-mount" in css
    for rule in ("width: 100%;", "height: 100%;", "min-height: 100%;"):
        assert rule in css
    assert "overflow-x: hidden;" in css, "horizontal scrolling must be forbidden"


def test_scrollbars_use_editor_theme_colors() -> None:
    css = _read(_STYLE)
    assert "::-webkit-scrollbar {" in css
    assert "::-webkit-scrollbar-track {" in css
    assert "::-webkit-scrollbar-thumb {" in css
    assert "background: var(--editor-bg, #fffdf7);" in css
    assert "background: var(--editor-muted, #6e6a61);" in css


def test_theme_propagates_to_page_root_and_mount() -> None:
    ts = _read(_EDITOR_TS)
    assert "document.documentElement" in ts
    assert 'document.getElementById("editor-mount")' in ts
    assert "root.style.setProperty(key, value)" in ts


def test_webengine_view_has_explicit_background_color() -> None:
    qml = _read(_WEBVIEW_QML)
    # Explicit canvas color in both routes: native-glass neutral editor sheet
    # and the regular theme editor color.
    assert "backgroundColor:" in qml
    assert "Theme.tokens.nativeGlass.editorTint" in qml
    assert "Theme.tokens.color.bgEditor" in qml


def test_agent_dock_geometry_switches_in_one_step() -> None:
    """Ideal-UI spec 10.1: dock and sidebar never animate around WebEngine.

    C1.5 gated the width animation off only in WebEngine mode; the ideal-UI
    spec makes one-step geometry switches the rule for every mode, with the
    panel content fading in/out instead and dragging committing on release.
    """
    dock = _read(_DOCK_QML)
    assert "Behavior on Layout.preferredWidth" not in dock
    assert "panelFadeIn" in dock and "panelFadeOut" in dock
    assert "beginResizeDrag" in dock and "commitResizeDrag" in dock
    assert "agentDragPreview" in dock
    app = _read(_APP_QML)
    assert "animateWidth" not in app
    assert "Behavior on Layout.preferredWidth" not in app
