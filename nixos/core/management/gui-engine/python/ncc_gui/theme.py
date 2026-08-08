"""Shared stylesheet + helpers for end-user friendly NCC GUI.

Layout rules: see doc/GUI-DESIGN.md (binding).
"""

from __future__ import annotations

# Prefer palette() for Plasma light/dark. Buttons MUST have a visible border.
APP_STYLE = """
QMainWindow, QWidget#nccShellRoot {
  background: palette(window);
  color: palette(window-text);
}
QListWidget#nccNav {
  background: palette(base);
  border: none;
  border-right: 1px solid palette(mid);
  padding: 8px 4px;
  outline: none;
  font-size: 13px;
  color: palette(window-text);
}
QListWidget#nccNav::item {
  padding: 10px 12px;
  border-radius: 8px;
  margin: 2px 6px;
  color: palette(window-text);
}
QListWidget#nccNav::item:selected {
  background: palette(highlight);
  color: palette(highlighted-text);
}
QListWidget#nccNav::item:disabled {
  color: palette(placeholder-text);
}
QLabel#nccPageTitle {
  font-size: 20px;
  font-weight: 700;
  padding: 4px 0 2px 0;
  color: palette(window-text);
}
QLabel#nccPageSubtitle,
QLabel#nccMuted {
  font-size: 13px;
  font-weight: 400;
  color: palette(window-text);
  padding-bottom: 8px;
}
QGroupBox {
  font-weight: 600;
  color: palette(window-text);
  border: 1px solid palette(mid);
  border-radius: 10px;
  margin-top: 12px;
  padding: 12px 10px 10px 10px;
}
QGroupBox::title {
  subcontrol-origin: margin;
  left: 12px;
  padding: 0 6px;
  color: palette(window-text);
}
QPushButton {
  border: 1px solid palette(mid);
  border-radius: 8px;
  padding: 8px 14px;
  font-weight: 600;
  background: palette(button);
  color: palette(button-text);
}
QPushButton:hover {
  border-color: palette(highlight);
}
QPushButton:disabled {
  color: palette(placeholder-text);
}
QComboBox, QLineEdit {
  border: 1px solid palette(mid);
  border-radius: 6px;
  padding: 4px 8px;
  min-height: 24px;
  color: palette(window-text);
  background: palette(base);
}
QTextEdit#nccActivityLog {
  border: 1px solid palette(mid);
  border-radius: 8px;
  background: palette(base);
  color: palette(window-text);
  font-family: monospace;
  font-size: 11px;
}
QFrame#nccDisabledBanner {
  background: palette(alternate-base);
  border: 1px solid palette(mid);
  border-radius: 12px;
  color: palette(window-text);
}
"""
