"""Capture BlockHelm Parity Mode under a fixed high-contrast backdrop.

Run while ``stripe_backdrop_window.py --split`` is on screen (left red, right
cyan). Captures the four parity modes from the real screen and prints a
title-bar strip statistic so Qt/DWM behaviour can be compared with the WPF
demo under identical conditions.

Usage:
    1. .\.venv\Scripts\python.exe scripts\stripe_backdrop_window.py --split --seconds 600
    2. .\.venv\Scripts\python.exe scripts\capture_blockhelm_parity.py
"""

from __future__ import annotations

import ctypes
import os
import statistics
import sys
import time
from pathlib import Path

if "--windowed" not in sys.argv:
    sys.argv.append("--windowed")

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from PySide6.QtCore import Q_ARG, QMetaObject, QUrl  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402
from PySide6.QtQuick import QQuickWindow  # noqa: E402

from ai_novel_studio.ui_qml.bootstrap import (  # noqa: E402
    NativeGlassBridge,
    blockhelm_parity_qml_path,
    register_frontend_types,
)

OUT_DIR = (
    Path(__file__).resolve().parent.parent
    / "docs"
    / "frontend"
    / "screenshots"
)


def _strip_stats(image, x0f: float, x1f: float, y0f: float, y1f: float) -> None:
    x0 = round(image.width() * x0f)
    x1 = round(image.width() * x1f)
    y0 = round(image.height() * y0f)
    y1 = round(image.height() * y1f)
    rs: list[int] = []
    gs: list[int] = []
    bs: list[int] = []
    colors: set[tuple[int, int, int]] = set()
    for y in range(y0, y1):
        for x in range(x0, x1):
            c = image.pixelColor(x, y)
            colors.add((c.red(), c.green(), c.blue()))
            rs.append(c.red())
            gs.append(c.green())
            bs.append(c.blue())
    print(
        f"  strip unique={len(colors)} "
        f"mean=({statistics.fmean(rs):.0f},{statistics.fmean(gs):.0f},"
        f"{statistics.fmean(bs):.0f}) "
        f"std=({statistics.pstdev(rs):.1f},{statistics.pstdev(gs):.1f},"
        f"{statistics.pstdev(bs):.1f})"
    )


def _capture(app: QGuiApplication, root: QQuickWindow, mode: str) -> None:
    ok = QMetaObject.invokeMethod(root, "selectMode", Q_ARG(str, mode))
    assert ok, f"selectMode({mode}) failed"
    # Force the parity window above the full-screen stripe backdrop so the
    # real-screen grab shows THIS window, not the stripe window.
    _make_topmost(root)
    _pump(app, 8)
    time.sleep(0.6)
    _pump(app, 4)

    screen = root.screen() or QGuiApplication.primaryScreen()
    assert screen is not None
    full = screen.grabWindow(0).toImage()
    dpr = float(screen.devicePixelRatio())
    geo = root.geometry()
    sg = screen.geometry()
    x = round((geo.x() - sg.x()) * dpr)
    y = round((geo.y() - sg.y()) * dpr)
    w = round(geo.width() * dpr)
    h = round(geo.height() * dpr)
    crop = full.copy(x, y, w, h)
    out = OUT_DIR / f"blockhelm-parity-{mode}.png"
    assert crop.save(str(out)), f"failed to save {out}"
    print(f"  saved {out} ({crop.width()}x{crop.height()})")
    # Title-bar strip (y 1.5%..3.7%, x 30%..62%): pure wash area.
    _strip_stats(crop, 0.30, 0.62, 0.015, 0.037)


def _make_topmost(window: QQuickWindow) -> None:
    if os.name != "nt":
        return
    try:
        hwnd = ctypes.wintypes.HWND(int(window.winId()))
    except (AttributeError, TypeError, ValueError):
        return
    user32 = ctypes.WinDLL("user32")
    user32.SetWindowPos(
        hwnd, ctypes.wintypes.HWND(-1), 0, 0, 0, 0,  # HWND_TOPMOST
        0x0001 | 0x0002 | 0x0010,
    )


def _pump(app: QGuiApplication, rounds: int = 8) -> None:
    for _ in range(rounds):
        app.processEvents()
        time.sleep(0.03)


def main() -> int:
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(Path(blockhelm_parity_qml_path()).parent))
    _, theme = register_frontend_types(engine)
    QQuickWindow.setDefaultAlphaBuffer(True)
    bridge = NativeGlassBridge(engine)
    engine.rootContext().setContextProperty("NativeGlassBridge", bridge)
    engine.load(QUrl.fromLocalFile(str(blockhelm_parity_qml_path())))
    if not engine.rootObjects():
        raise RuntimeError("BlockHelmParity.qml failed to load")
    root = engine.rootObjects()[0]
    assert isinstance(root, QQuickWindow)
    bridge.setWindow(root)
    bridge.setDarkMode(True)
    bridge.apply("acrylic")
    root.show()
    _make_topmost(root)
    _pump(app, 8)
    time.sleep(1.0)
    _make_topmost(root)
    _pump(app, 8)
    for _ in range(30):
        if bool(root.property("nativeActive")):
            break
        bridge.refresh()
        _make_topmost(root)
        _pump(app, 4)
        time.sleep(0.15)
    print(f"nativeActive={bool(root.property('nativeActive'))}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for mode in ("solid", "transparent", "acrylic", "parity"):
        _capture(app, root, mode)

    engine.deleteLater()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
