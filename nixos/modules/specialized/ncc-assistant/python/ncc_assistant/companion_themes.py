"""Companion chrome themes (dark by default — overlay must stay readable)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

DEFAULT_THEME = "dark"

THEME_LABELS: dict[str, str] = {
    "dark": "Dark",
    "midnight": "Midnight",
    "light": "Light",
}


@dataclass(frozen=True)
class CompanionTheme:
    id: str
    label: str
    # Surfaces
    glass_bg: str
    glass_border: str
    base: str
    alt: str
    button: str
    border: str
    # Text
    text: str
    muted: str
    # Accent / selection
    accent: str
    accent_text: str
    # Scrollbar
    scroll: str
    scroll_hover: str


THEMES: dict[str, CompanionTheme] = {
    "dark": CompanionTheme(
        id="dark",
        label="Dark",
        glass_bg="rgba(28, 32, 38, 236)",
        glass_border="rgba(120, 140, 160, 70)",
        base="#1e2430",
        alt="#252b38",
        button="#2a3140",
        border="#3d4658",
        text="#e8ecf2",
        muted="#9aa3b5",
        accent="#5b8def",
        accent_text="#ffffff",
        scroll="#3d4658",
        scroll_hover="#5b8def",
    ),
    "midnight": CompanionTheme(
        id="midnight",
        label="Midnight",
        glass_bg="rgba(12, 14, 22, 242)",
        glass_border="rgba(90, 100, 140, 80)",
        base="#10131c",
        alt="#161a26",
        button="#1a2030",
        border="#2c3448",
        text="#dce3f0",
        muted="#8b94a8",
        accent="#7c6af5",
        accent_text="#ffffff",
        scroll="#2c3448",
        scroll_hover="#7c6af5",
    ),
    "light": CompanionTheme(
        id="light",
        label="Light",
        glass_bg="rgba(244, 246, 248, 236)",
        glass_border="rgba(80, 90, 100, 90)",
        base="#ffffff",
        alt="#eef1f5",
        button="#ffffff",
        border="#c5ccd4",
        text="#1a1a1a",
        muted="#667788",
        accent="#3d5a80",
        accent_text="#ffffff",
        scroll="#c5ccd4",
        scroll_hover="#3d5a80",
    ),
}


def normalize_theme_id(theme_id: str | None) -> str:
    key = (theme_id or "").strip().lower()
    if key in THEMES:
        return key
    return DEFAULT_THEME


def list_themes() -> list[tuple[str, str]]:
    return [(t.id, t.label) for t in THEMES.values()]


def get_theme(theme_id: str | None) -> CompanionTheme:
    return THEMES[normalize_theme_id(theme_id)]


def stylesheet_for(theme: CompanionTheme) -> str:
    t = theme
    return f"""
    QFrame#glass {{
      background: {t.glass_bg};
      border: 1px solid {t.glass_border};
      border-radius: 14px;
    }}
    QWidget {{
      color: {t.text};
    }}
    QLabel {{
      color: {t.text};
      background: transparent;
    }}
    QLabel#nccMuted {{
      color: {t.muted};
      font-size: 10px;
      background: transparent;
    }}
    QTextEdit, QLineEdit, QListWidget, QComboBox, QTextBrowser {{
      background: {t.base};
      border: 1px solid {t.border};
      border-radius: 8px;
      padding: 4px;
      color: {t.text};
      selection-background-color: {t.accent};
      selection-color: {t.accent_text};
    }}
    QLineEdit::placeholder, QTextEdit::placeholder {{
      color: {t.muted};
    }}
    QListWidget::item {{
      color: {t.text};
      padding: 3px 4px;
    }}
    QListWidget::item:selected {{
      background: {t.accent};
      color: {t.accent_text};
    }}
    QListWidget::item:hover {{
      background: {t.alt};
    }}
    QComboBox {{
      combobox-popup: 0;
      padding: 3px 6px;
    }}
    QComboBox:drop-down {{
      border: none;
      width: 18px;
    }}
    QComboBox QAbstractItemView {{
      background: {t.base};
      color: {t.text};
      border: 1px solid {t.border};
      selection-background-color: {t.accent};
      selection-color: {t.accent_text};
      outline: 0;
    }}
    QComboBox QAbstractItemView::item {{
      min-height: 22px;
      padding: 2px 6px;
      color: {t.text};
    }}
    QPushButton, QToolButton {{
      border-radius: 6px;
      padding: 4px 6px;
      background: {t.button};
      border: 1px solid {t.border};
      color: {t.text};
    }}
    QPushButton:hover, QToolButton:hover {{
      background: {t.alt};
      border-color: {t.accent};
    }}
    QToolButton:checked {{
      background: {t.accent};
      color: {t.accent_text};
      border-color: {t.accent};
    }}
    QMenu {{
      background: {t.base};
      color: {t.text};
      border: 1px solid {t.border};
      padding: 4px;
    }}
    QMenu::item {{
      padding: 4px 18px 4px 12px;
      color: {t.text};
      background: transparent;
    }}
    QMenu::item:selected {{
      background: {t.accent};
      color: {t.accent_text};
    }}
    QMenu::separator {{
      height: 1px;
      background: {t.border};
      margin: 4px 8px;
    }}
    QScrollBar:vertical {{
      background: {t.alt};
      width: 10px;
      margin: 0;
      border-radius: 5px;
    }}
    QScrollBar::handle:vertical {{
      background: {t.scroll};
      min-height: 24px;
      border-radius: 5px;
    }}
    QScrollBar::handle:vertical:hover {{
      background: {t.scroll_hover};
    }}
    QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
      height: 0;
    }}
    QScrollArea {{
      background: transparent;
      border: none;
    }}
    QSizeGrip {{
      width: 14px;
      height: 14px;
    }}
    """


def apply_palette(target: Any, theme: CompanionTheme) -> None:
    """Push QPalette so child widgets using palette(...) (ThinkingBlock) match."""
    from PySide6.QtGui import QColor, QPalette

    pal = QPalette()
    roles = {
        QPalette.ColorRole.Window: theme.alt,
        QPalette.ColorRole.WindowText: theme.text,
        QPalette.ColorRole.Base: theme.base,
        QPalette.ColorRole.AlternateBase: theme.alt,
        QPalette.ColorRole.Text: theme.text,
        QPalette.ColorRole.Button: theme.button,
        QPalette.ColorRole.ButtonText: theme.text,
        QPalette.ColorRole.BrightText: theme.accent_text,
        QPalette.ColorRole.Highlight: theme.accent,
        QPalette.ColorRole.HighlightedText: theme.accent_text,
        QPalette.ColorRole.PlaceholderText: theme.muted,
        QPalette.ColorRole.Mid: theme.muted,
        QPalette.ColorRole.Dark: theme.border,
        QPalette.ColorRole.Light: theme.alt,
        QPalette.ColorRole.ToolTipBase: theme.base,
        QPalette.ColorRole.ToolTipText: theme.text,
    }
    for role, hex_color in roles.items():
        pal.setColor(role, QColor(hex_color))
    target.setPalette(pal)
