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
/* Form status values — no extra bottom padding (that clips in QFormLayout). */
QLabel#nccFormValue {
  font-size: 13px;
  font-weight: 400;
  color: palette(window-text);
  padding: 0;
  margin: 0;
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
QPushButton#nccPrimaryButton {
  border-color: palette(highlight);
  font-weight: 700;
}
QToolButton#nccHeaderAction {
  border: 1px solid palette(mid);
  border-radius: 8px;
  padding: 6px;
  background: palette(button);
}
QToolButton#nccHeaderAction:hover {
  border-color: palette(highlight);
}
QGroupBox#nccPageFooter {
  margin-top: 4px;
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
QTextEdit#nccPtyTerminal {
  border: 1px solid palette(mid);
  border-radius: 8px;
  background: #0d1117;
  color: #e5e5e5;
  font-family: monospace;
  font-size: 10pt;
  padding: 6px;
}
QFrame#nccDisabledBanner {
  background: palette(alternate-base);
  border: 1px solid palette(mid);
  border-radius: 12px;
  color: palette(window-text);
}
QFrame#nccGateBanner {
  background: palette(alternate-base);
  border: none;
  border-bottom: 1px solid palette(mid);
  color: palette(window-text);
}
QFrame#nccGateBanner[gateKind="danger"] {
  background: #3d1515;
  border-bottom: 2px solid #c44;
  color: #f5d0d0;
}
QFrame#nccGateBanner[gateKind="warn"] {
  background: #3d3010;
  border-bottom: 2px solid #c90;
  color: #f5e6c0;
}
QFrame#nccGateBanner[gateKind="info"] {
  background: palette(alternate-base);
  border-bottom: 1px solid palette(highlight);
}
QLabel#nccGateMessage {
  font-size: 13px;
  font-weight: 600;
  color: inherit;
  padding: 2px 0;
}
QWidget#nccTargetBar {
  border: none;
  border-bottom: 1px solid palette(mid);
  max-height: 48px;
}
QWidget#nccTargetBar[sessionMode="remote"] {
  background: #0f2a1f;
  border-bottom: 2px solid #2a8f5b;
}
QWidget#nccTargetBar[sessionMode="pending"],
QWidget#nccTargetBar[sessionMode="connecting"] {
  background: #2a2410;
  border-bottom: 2px solid #c90;
}
QWidget#nccTargetBar[sessionMode="failed"] {
  background: #2a1212;
  border-bottom: 2px solid #c44;
}
QLabel#nccSessionChip {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.02em;
  padding: 4px 10px;
  border-radius: 6px;
  border: 1px solid palette(mid);
  background: palette(button);
  color: palette(button-text);
}
QLabel#nccSessionChip[sessionMode="local"] {
  border-color: palette(mid);
}
QLabel#nccSessionChip[sessionMode="remote"] {
  border-color: #2a8f5b;
  background: #1a3d2c;
  color: #b8f0d0;
}
QLabel#nccSessionChip[sessionMode="pending"],
QLabel#nccSessionChip[sessionMode="connecting"] {
  border-color: #c90;
  background: #3d3010;
  color: #ffe6a0;
}
QLabel#nccSessionChip[sessionMode="failed"] {
  border-color: #c44;
  background: #4a1818;
  color: #ffc0c0;
}
QLabel#nccOperatingScope {
  font-size: 12px;
  font-weight: 600;
  color: palette(window-text);
  padding: 0 0 6px 0;
}
QLabel#nccOperatingScope[sessionMode="remote"] {
  color: #6dcb9a;
}
QLabel#nccOperatingScope[sessionMode="pending"],
QLabel#nccOperatingScope[sessionMode="connecting"] {
  color: #e0b84a;
}
QLabel#nccOperatingScope[sessionMode="failed"] {
  color: #e07070;
}
QLabel#nccTargetStatus {
  font-size: 12px;
  font-weight: 400;
  color: palette(window-text);
  padding: 0;
  margin: 0;
}
"""
