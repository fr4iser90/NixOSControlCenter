"""Provider add/edit dialog (masked keys + modular headers)."""

from __future__ import annotations

from urllib.parse import urlparse

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMessageBox,
    QPushButton,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from .auth import apply_api_key, load_cached_auth
from .config import Settings, normalize_endpoint, resolve_api
from .providers import (
    Provider,
    add_provider,
    normalize_auth_header,
    new_provider_id,
    update_provider,
)


class ProviderEditorDialog(QDialog):
    """Create or edit a provider: endpoint, auth header, extra headers, API key."""

    def __init__(
        self,
        *,
        provider: Provider | None = None,
        parent: QWidget | None = None,
    ) -> None:
        super().__init__(parent)
        self._existing = provider
        self.result_provider: Provider | None = None
        self.setWindowTitle("Edit provider" if provider else "Add provider")
        self.setModal(True)
        self.resize(520, 480)

        layout = QVBoxLayout(self)
        form = QFormLayout()

        self.name_edit = QLineEdit()
        self.name_edit.setPlaceholderText("Display name")
        form.addRow("Name", self.name_edit)

        self.endpoint_edit = QLineEdit()
        self.endpoint_edit.setPlaceholderText("https://…/v1")
        form.addRow("Endpoint", self.endpoint_edit)

        self.api_combo = QComboBox()
        self.api_combo.addItem("OpenAI-compatible", "openai-compatible")
        self.api_combo.addItem("Anthropic", "anthropic")
        form.addRow("API", self.api_combo)

        self.auth_combo = QComboBox()
        self.auth_combo.addItem("Authorization (Bearer)", "bearer")
        self.auth_combo.addItem("X-API-KEY", "X-API-KEY")
        self.auth_combo.addItem("x-api-key", "x-api-key")
        self.auth_combo.addItem("x-ai-key", "x-ai-key")
        self.auth_combo.addItem("Custom…", "custom")
        self.auth_combo.currentIndexChanged.connect(self._on_auth_mode)
        form.addRow("API key header", self.auth_combo)

        self.auth_custom = QLineEdit()
        self.auth_custom.setPlaceholderText("Custom header name")
        self.auth_custom.hide()
        form.addRow("", self.auth_custom)

        self.key_edit = QLineEdit()
        self.key_edit.setEchoMode(QLineEdit.EchoMode.Password)
        self.key_edit.setPlaceholderText("••••••••  (leave blank to keep saved key)")
        form.addRow("API key", self.key_edit)

        layout.addLayout(form)

        layout.addWidget(QLabel("Extra headers (optional — e.g. OpenAI-Organization, x-ai-*)"))
        self.headers = QTableWidget(0, 2)
        self.headers.setHorizontalHeaderLabels(["Header", "Value"])
        self.headers.horizontalHeader().setStretchLastSection(True)
        self.headers.setMinimumHeight(140)
        layout.addWidget(self.headers)

        hrow = QHBoxLayout()
        add_h = QPushButton("Add header")
        add_h.clicked.connect(self._add_header_row)
        rm_h = QPushButton("Remove row")
        rm_h.clicked.connect(self._remove_header_row)
        hrow.addWidget(add_h)
        hrow.addWidget(rm_h)
        hrow.addStretch()
        layout.addLayout(hrow)

        hint = QLabel(
            "API keys are stored in ~/.config/ncc-assistant/credentials.json (0600), "
            "not in systemConfig. Extra header values that look like secrets are masked here."
        )
        hint.setWordWrap(True)
        hint.setStyleSheet("color: palette(placeholder-text);")
        layout.addWidget(hint)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Save | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self._save)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

        if provider:
            self._load(provider)
        else:
            self._add_header_row()

    def _on_auth_mode(self, _index: int = 0) -> None:
        custom = self.auth_combo.currentData() == "custom"
        self.auth_custom.setVisible(custom)

    def _load(self, provider: Provider) -> None:
        self.name_edit.setText(provider.name)
        self.endpoint_edit.setText(provider.endpoint)
        idx = self.api_combo.findData(provider.api)
        if idx >= 0:
            self.api_combo.setCurrentIndex(idx)

        auth = provider.auth_header
        if not auth:
            self.auth_combo.setCurrentIndex(self.auth_combo.findData("bearer"))
        else:
            found = self.auth_combo.findData(auth)
            if found >= 0:
                self.auth_combo.setCurrentIndex(found)
            else:
                self.auth_combo.setCurrentIndex(self.auth_combo.findData("custom"))
                self.auth_custom.setText(auth)
        self._on_auth_mode()

        key, _hdr = load_cached_auth(provider.endpoint)
        if key:
            self.key_edit.setPlaceholderText("••••••••  (saved — leave blank to keep)")

        self.headers.setRowCount(0)
        for name, value in provider.extra_headers.items():
            self._add_header_row(name, value)
        if self.headers.rowCount() == 0:
            self._add_header_row()

    def _add_header_row(
        self,
        name: str = "",
        value: str = "",
        *,
        mask: bool = True,
    ) -> None:
        del mask  # always mask values in the editor
        row = self.headers.rowCount()
        self.headers.insertRow(row)
        self.headers.setItem(row, 0, QTableWidgetItem(name))
        edit = QLineEdit(value)
        edit.setEchoMode(QLineEdit.EchoMode.Password)
        edit.setPlaceholderText("value")
        self.headers.setCellWidget(row, 1, edit)

    def _remove_header_row(self) -> None:
        row = self.headers.currentRow()
        if row >= 0:
            self.headers.removeRow(row)

    def _auth_header_value(self) -> str | None:
        mode = str(self.auth_combo.currentData() or "bearer")
        if mode == "bearer":
            return None
        if mode == "custom":
            return normalize_auth_header(self.auth_custom.text())
        return normalize_auth_header(mode)

    def _collect_extra_headers(self) -> dict[str, str]:
        out: dict[str, str] = {}
        for row in range(self.headers.rowCount()):
            name_item = self.headers.item(row, 0)
            name = (name_item.text() if name_item else "").strip()
            if not name:
                continue
            cell = self.headers.cellWidget(row, 1)
            if isinstance(cell, QLineEdit):
                value = cell.text().strip()
            else:
                val_item = self.headers.item(row, 1)
                value = (val_item.text() if val_item else "").strip()
            if value:
                out[name] = value
        return out

    def _save(self) -> None:
        name = self.name_edit.text().strip()
        endpoint = self.endpoint_edit.text().strip()
        if not endpoint:
            QMessageBox.warning(self, "Provider", "Endpoint is required.")
            return
        ep = normalize_endpoint(endpoint)
        if not name:
            name = urlparse(ep).netloc or ep
        api = resolve_api(str(self.api_combo.currentData() or "openai-compatible"), None)
        auth = self._auth_header_value()
        extras = self._collect_extra_headers()

        try:
            if self._existing:
                prov = Provider(
                    id=self._existing.id,
                    name=name,
                    api=api,
                    endpoint=ep,
                    auth_header=auth,
                    extra_headers=extras,
                )
                update_provider(prov)
            else:
                prov = add_provider(
                    name=name,
                    endpoint=ep,
                    api=api,
                    provider_id=new_provider_id(),
                    auth_header=auth,
                    extra_headers=extras,
                )
        except Exception as exc:
            QMessageBox.warning(self, "Provider", str(exc))
            return

        key = self.key_edit.text().strip()
        if key:
            try:
                # Build minimal settings for validation + credential cache
                base = Settings.from_env(client_mode="chat")
                from dataclasses import replace

                trial = replace(
                    base,
                    endpoint=prov.endpoint,
                    api=prov.api,
                    api_key=None,
                    api_header_name=prov.auth_header,
                    extra_headers=tuple(sorted(prov.extra_headers.items())),
                )
                apply_api_key(trial, key, preferred_header=prov.auth_header)
            except Exception as exc:
                QMessageBox.warning(
                    self,
                    "Provider",
                    f"Provider saved, but API key check failed:\n{exc}",
                )
                self.result_provider = prov
                self.accept()
                return

        self.result_provider = prov
        self.accept()


def edit_provider_dialog(
    parent: QWidget | None = None,
    *,
    provider: Provider | None = None,
) -> Provider | None:
    dlg = ProviderEditorDialog(provider=provider, parent=parent)
    if dlg.exec() != QDialog.DialogCode.Accepted:
        return None
    return dlg.result_provider
