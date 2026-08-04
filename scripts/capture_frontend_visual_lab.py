"""Capture the Visual V0 rework states (offscreen by default).

Usage (from the worktree root, using its venv):
    .\\.venv\\Scripts\\python.exe scripts\\capture_frontend_visual_lab.py
    .\\.venv\\Scripts\\python.exe scripts\\capture_frontend_visual_lab.py --windowed

Outputs (diagnosis doc §14):
    visual-v0-rework-safe.png
    visual-v0-rework-balanced.png
    visual-v0-rework-premium.png
    visual-v0-rework-paper.png
    visual-v0-rework-dark.png
    visual-v0-rework-resized.png

Before every capture the script asserts the full-window backdrop coverage and
that no near-black bare region exists (diagnosis doc §13.1/13.2).
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

if "--windowed" not in sys.argv:
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from PySide6.QtCore import QUrl  # noqa: E402
from PySide6.QtGui import QGuiApplication, QImage  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402
from PySide6.QtQuick import QQuickItem, QQuickWindow  # noqa: E402

from ai_novel_studio.ui_qml.bootstrap import (  # noqa: E402
    register_frontend_types,
    visual_lab_qml_path,
)

OUT_DIR = (
    Path(__file__).resolve().parent.parent
    / "docs"
    / "frontend"
    / "screenshots"
)


def _pump(app: QGuiApplication, rounds: int = 8) -> None:
    for _ in range(rounds):
        app.processEvents()
        time.sleep(0.03)


def _find_item(root: QQuickItem, name: str) -> QQuickItem | None:
    if root.objectName() == name:
        return root
    for child in root.childItems():
        found = _find_item(child, name)
        if found is not None:
            return found
    return None


def _assert_clean_window(window: QQuickWindow, image: QImage, label: str) -> None:
    """Diagnosis doc 13.1/13.2: backdrop covers the window; no black holes."""
    backdrop = _find_item(window.contentItem(), "labBackgroundLayer")
    assert backdrop is not None, f"{label}: backdrop missing"
    assert backdrop.x() == 0 and backdrop.y() == 0, f"{label}: backdrop offset"
    assert (
        abs(backdrop.width() - float(window.width())) < 1
        and abs(backdrop.height() - float(window.height())) < 1
    ), f"{label}: backdrop does not cover the window"

    # True bare regions are pure black (unpainted canvas). The dark theme's
    # canvas is #202124 (brightness ~36), which must NOT be flagged.
    dark = 0
    for y in range(0, image.height(), 8):
        for x in range(0, image.width(), 8):
            c = image.pixelColor(x, y)
            if max(c.red(), c.green(), c.blue()) < 12:
                dark += 1
    assert dark == 0, f"{label}: {dark} pure-black sampled pixels"


def main() -> int:
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(Path(visual_lab_qml_path()).parent))
    facade, theme = register_frontend_types(engine)
    engine.rootContext().setContextProperty("BackdropBridge", None)
    engine.load(QUrl.fromLocalFile(str(visual_lab_qml_path())))
    root = engine.rootObjects()[0]
    assert isinstance(root, QQuickWindow), "VisualLab window expected"
    root.show()
    _pump(app, 30 if "--windowed" in sys.argv else 12)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    def capture(
        theme_name: str,
        quality: str,
        filename: str,
        size: tuple[int, int] | None = None,
    ) -> None:
        theme.setTheme(theme_name)
        theme.setVisualQuality(quality)
        if size is not None:
            root.resize(*size)
        _pump(app, 12)
        image = root.grabWindow()
        _assert_clean_window(root, image, filename)
        path = OUT_DIR / filename
        assert image.save(str(path)), f"failed to save {path}"
        print(f"saved {path}")

    # Diagnosis doc §14 required shots.
    capture("paper", "safe", "visual-v0-rework-safe.png")
    capture("paper", "balanced", "visual-v0-rework-balanced.png")
    capture("paper", "premium", "visual-v0-rework-premium.png")
    capture("paper", "balanced", "visual-v0-rework-paper.png")
    capture("dark", "balanced", "visual-v0-rework-dark.png")
    capture("paper", "balanced", "visual-v0-rework-resized.png", size=(1280, 800))

    engine.deleteLater()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
