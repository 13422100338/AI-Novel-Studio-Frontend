"""Capture Visual V0 sample page states (offscreen, software rendering).

Usage (from the worktree root, using its venv):
    .\\.venv\\Scripts\\python.exe scripts\\capture_frontend_visual_lab.py

The original filenames (visual-lab-*.png) are the pre-rework "before" shots and
are kept untouched. The rework adds real-time Acrylic surfaces, so this script
now writes `visual-lab-glass-*.png` "after" shots plus a material-compare crop.
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from PySide6.QtCore import QUrl  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
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


def main() -> int:
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(Path(visual_lab_qml_path()).parent))
    facade, theme = register_frontend_types(engine)
    engine.load(QUrl.fromLocalFile(str(visual_lab_qml_path())))
    root = engine.rootObjects()[0]
    assert isinstance(root, QQuickWindow), "VisualLab window expected"
    root.show()
    _pump(app, 12)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    combos = (
        ("paper", "balanced", "visual-lab-glass-paper-balanced.png"),
        ("paper", "safe", "visual-lab-glass-paper-safe.png"),
        ("dark", "premium", "visual-lab-glass-dark-premium.png"),
        ("light", "safe", "visual-lab-glass-light-safe.png"),
    )
    for theme_name, quality, filename in combos:
        theme.setTheme(theme_name)
        theme.setVisualQuality(quality)
        _pump(app, 10)
        image = root.grabWindow()
        path = OUT_DIR / filename
        assert image.save(str(path)), f"failed to save {path}"
        print(f"saved {path}")

    # Glow success-state close-up (spec 8.1: success pins to green, no drift).
    theme.setTheme("paper")
    theme.setVisualQuality("balanced")
    glow = _find_item(root.contentItem(), "labStreamingGlow")
    if glow is not None:
        glow.setProperty("state", "success")
    _pump(app, 8)
    image = root.grabWindow()
    path = OUT_DIR / "visual-lab-glass-paper-glow-success.png"
    assert image.save(str(path)), f"failed to save {path}"
    print(f"saved {path}")

    engine.deleteLater()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
