"""BlockHelm Parity Mode: minimal Qt/DWM parity page (diagnosis only).

The page must stay deliberately neutral: fixed gray palette, no Theme tokens,
no in-app blur, four fixed modes (solid / transparent / acrylic / parity).
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest

# Offscreen + software rendering: no DWM, no real window (same rule as the
# other lab tests).
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import Q_ARG, QMetaObject, QUrl  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402
from PySide6.QtQuick import QQuickItem, QQuickWindow  # noqa: E402
from pytestqt.qtbot import QtBot  # noqa: E402

from ai_novel_studio.ui_qml.bootstrap import (  # noqa: E402
    blockhelm_parity_qml_path,
    register_frontend_types,
)

from .test_native_glass_lab import FakeNativeGlassBridge  # noqa: E402

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


def _load_parity(
    qtbot: QtBot,
) -> tuple[QQmlApplicationEngine, FakeNativeGlassBridge, QQuickWindow]:
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(Path(blockhelm_parity_qml_path()).parent))
    facade, theme = register_frontend_types(engine)
    bridge = FakeNativeGlassBridge()
    engine.rootContext().setContextProperty("NativeGlassBridge", bridge)
    engine.load(QUrl.fromLocalFile(str(blockhelm_parity_qml_path())))
    assert engine.rootObjects(), "BlockHelmParity.qml failed to load"
    _ACTIVE_ENGINES.append(engine)
    window = engine.rootObjects()[0]
    assert isinstance(window, QQuickWindow)
    return engine, bridge, window


def test_parity_page_loads_and_defaults_to_parity_mode(qtbot: QtBot) -> None:
    engine, _, window = _load_parity(qtbot)
    assert window.property("mode") == "parity"
    assert window.property("cardsVisible") is True
    # Fixed neutral palette, never from Theme.
    assert window.property("_PANEL_A") == pytest.approx(0.45)
    assert window.property("_SIDEBAR_A") == pytest.approx(0.52)


def test_parity_mode_switch_applies_dwm(qtbot: QtBot) -> None:
    engine, bridge, window = _load_parity(qtbot)
    # Find and click the mode buttons.
    for key, expected_kind in (
        ("solid", "none"),
        ("transparent", "none"),
        ("acrylic", "acrylic"),
        ("parity", "acrylic"),
    ):
        ok = QMetaObject.invokeMethod(window, "selectMode", Q_ARG(str, key))
        assert ok, f"selectMode({key}) failed"
        qtbot.wait(30)
        assert window.property("mode") == key
        assert bridge.calls[-1] == expected_kind, f"{key} should apply {expected_kind}"
        if key in ("solid", "transparent"):
            assert window.property("nativeActive") is False
        else:
            bridge.apply_result = True
            bridge.apply("acrylic")
            qtbot.wait(30)
            assert window.property("nativeActive") is True


def test_parity_cards_only_in_parity_mode(qtbot: QtBot) -> None:
    engine, _, window = _load_parity(qtbot)
    assert window.property("cardsVisible") is True
    assert window.property("statusOnly") is False
    window.setProperty("mode", "acrylic")
    qtbot.wait(30)
    assert window.property("cardsVisible") is False
    assert window.property("statusOnly") is True
