from PySide6.QtCore import QObject

from ai_novel_studio.ui_qml.bridge.theme_provider import ThemeProvider


def test_default_theme_is_paper() -> None:
    theme = ThemeProvider()
    assert theme.property("themeName") == "paper"
    tokens = theme.property("tokens")
    assert tokens["color"]["bgCanvas"] == "#F3EFE6"
    assert tokens["spacing"]["lg"] == 16
    assert tokens["radius"]["r16"] == 16
    assert tokens["duration"]["panel"] == 220
    assert tokens["duration"]["panelFade"] == 140
    assert tokens["color"]["scrim"] == "#80000000"
    material = tokens["material"]
    assert material["glassBlurBalanced"] == "24"
    assert material["glassBlurPremium"] == "40"
    assert material["glassTintOpacity"] == "0.62"
    assert material["acrylicTint"] == "#FBF8F0"


def test_set_theme_valid_and_invalid() -> None:
    theme = ThemeProvider()
    theme.setTheme("dark")
    assert theme.property("themeName") == "dark"
    assert theme.property("tokens")["color"]["bgCanvas"] == "#202124"
    assert theme.property("tokens")["material"]["acrylicTint"] == "#292A2D"
    theme.setTheme("unknown")
    assert theme.property("themeName") == "paper"


def test_next_theme_cycles() -> None:
    theme = ThemeProvider("dark")
    assert theme.nextThemeName() == "paper"
    theme.setTheme("light")
    assert theme.nextThemeName() == "dark"
    theme.setTheme("paper")
    assert theme.nextThemeName() == "light"


def test_theme_provider_is_qobject() -> None:
    assert isinstance(ThemeProvider(), QObject)
