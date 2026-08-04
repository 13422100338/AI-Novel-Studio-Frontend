"""Windows 11 system backdrop (Mica / Desktop Acrylic) for the Visual V0 lab.

ideal-UI spec 12: system material is an optional enhancement; the app must
render correctly without it. The production shell keeps its opaque,
WebEngine-safe background until Visual V4 is evaluated; this bridge is
consumed only by the standalone ``--visual-lab`` experiment page.

The DWM-drawn backdrop (wallpaper blur behind the whole window) is requested
with ``DwmSetWindowAttribute(DWMWA_SYSTEMBACKDROP_TYPE)``:

- ``DWMSBT_MAINWINDOW (2)``       -> Mica
- ``DWMSBT_TRANSIENTWINDOW (3)``  -> Desktop Acrylic (brighter)
- ``DWMSBT_TABBEDWINDOW (4)``     -> Mica Alt

Requires Windows 11 build 22621+; every failure path returns ``False`` so the
caller renders a normal opaque window.
"""

from __future__ import annotations

import ctypes
import os
import sys
from ctypes import wintypes
from typing import Any

# dwmapi.h: DwmSetWindowAttribute attribute id for DWM_SYSTEMBACKDROP_TYPE.
_DWMWA_SYSTEMBACKDROP_TYPE = 38

DWMSBT_MAINWINDOW = 2
DWMSBT_TRANSIENTWINDOW = 3
DWMSBT_TABBEDWINDOW = 4
DWMSBT_NONE = 1

# Windows 11 22H2 (first build with the documented system-backdrop enum).
_MIN_BUILD = 22621

_BACKDROP_KINDS = {
    "none": DWMSBT_NONE,
    "mica": DWMSBT_MAINWINDOW,
    "acrylic": DWMSBT_TRANSIENTWINDOW,
    "mica-alt": DWMSBT_TABBEDWINDOW,
}


def _windows_build() -> int:
    """Return the current Windows build number, or 0 on non-Windows."""
    if os.name != "nt":
        return 0
    version_getter = getattr(sys, "getwindowsversion", None)
    if version_getter is None:
        return 0
    try:
        return int(version_getter().build)
    except (AttributeError, OSError, TypeError, ValueError):
        return 0


def _dwm_set_backdrop(hwnd: int, backdrop_type: int) -> bool:
    """Call DwmSetWindowAttribute; False on any failure (never raises)."""
    try:
        library_factory = getattr(ctypes, "WinDLL", None)
        if library_factory is None:
            return False
        dwmapi = library_factory("dwmapi")
        setter = dwmapi.DwmSetWindowAttribute
        setter.restype = ctypes.c_long
        setter.argtypes = [
            wintypes.HWND,
            ctypes.c_uint,
            wintypes.LPVOID,
            ctypes.c_uint,
        ]
        attribute = ctypes.c_uint(_DWMWA_SYSTEMBACKDROP_TYPE)
        value = ctypes.c_int(backdrop_type)
        result = setter(
            wintypes.HWND(int(hwnd)),
            attribute,
            ctypes.byref(value),
            ctypes.sizeof(value),
        )
        return int(result) == 0
    except (AttributeError, OSError, TypeError, ValueError):
        return False


def apply_system_backdrop(window: Any, kind: str = "mica") -> bool:
    """Apply a DWM-drawn backdrop behind ``window`` (a QQuickWindow).

    Returns True when the DWM call succeeded; False on unsupported OS, missing
    API, or any failure. Callers must treat False as "render normally".
    """
    if _windows_build() < _MIN_BUILD:
        return False
    backdrop_type = _BACKDROP_KINDS.get(kind)
    if backdrop_type is None:
        return False
    try:
        hwnd = int(window.winId())
    except (AttributeError, TypeError, ValueError):
        return False
    return _dwm_set_backdrop(hwnd, backdrop_type)
