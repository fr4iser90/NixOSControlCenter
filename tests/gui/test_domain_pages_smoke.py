#!/usr/bin/env python3
"""Smoke: every module ui/gui/page.py must construct without import/attr errors.

Catches regressions like ChatPage missing on_confirm_request before deploy.

  python3 tests/gui/test_domain_pages_smoke.py
"""

from __future__ import annotations

import ast
import importlib.util
import os
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
NIXOS = REPO / "nixos"
GUI_PY = NIXOS / "core/management/gui-engine/python"
ASSISTANT_PY = NIXOS / "modules/specialized/ncc-assistant/python"
ASSISTANT_GUI = ASSISTANT_PY / "ncc_assistant/gui.py"


def _discover_page_files() -> list[Path]:
    return sorted(NIXOS.rglob("ui/gui/page.py"))


def _load_page_module(path: Path):
    rel = path.relative_to(NIXOS)
    mod_name = "ncc_page_" + "_".join(rel.parts).replace(".", "_").replace("-", "_")
    # Sibling imports (intent_store, preflight, …) live next to page.py
    sibling = str(path.parent)
    if sibling not in sys.path:
        sys.path.insert(0, sibling)
    spec = importlib.util.spec_from_file_location(mod_name, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    # dataclasses need the module registered before exec_module
    sys.modules[mod_name] = mod
    spec.loader.exec_module(mod)
    return mod


def _class_has_method(path: Path, class_name: str, method_name: str) -> bool:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    for node in tree.body:
        if not isinstance(node, ast.ClassDef) or node.name != class_name:
            continue
        for item in node.body:
            if isinstance(item, ast.FunctionDef) and item.name == method_name:
                return True
    return False


class DomainPagesSmoke(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        for p in (GUI_PY, ASSISTANT_PY):
            ps = str(p)
            if ps not in sys.path:
                sys.path.insert(0, ps)
        os.environ.setdefault(
            "NCC_HOST_POLICY", '{"dangerousIgnore":false,"autoBuild":false}'
        )
        os.environ.setdefault("NCC_GUI_CATALOG", "[]")
        # Point packages/catalog at the *repo* tree — never live /etc/nixos in tests.
        os.environ["NIXOS_DIR"] = str(NIXOS)
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        # Avoid modal error popups during create_page() (catalog / remote / ncc misses).
        import ncc_gui.dialogs as dialogs

        cls._orig_error = dialogs.error
        dialogs.error = lambda *a, **k: None  # type: ignore[assignment]
        dialogs.info = lambda *a, **k: None  # type: ignore[assignment]
        dialogs.confirm = lambda *a, **k: False  # type: ignore[assignment]

    @classmethod
    def tearDownClass(cls) -> None:
        try:
            import ncc_gui.dialogs as dialogs

            if getattr(cls, "_orig_error", None) is not None:
                dialogs.error = cls._orig_error
        except Exception:
            pass

    def test_assistant_chat_page_ast_has_confirm_handler(self) -> None:
        """Regression: ChatPage must define on_confirm_request (no Qt needed)."""
        self.assertTrue(
            ASSISTANT_GUI.is_file(),
            f"missing {ASSISTANT_GUI}",
        )
        self.assertTrue(
            _class_has_method(ASSISTANT_GUI, "ChatPage", "on_confirm_request"),
            "ChatPage.on_confirm_request missing — ConfirmBridge.ask will crash",
        )
        self.assertTrue(
            _class_has_method(ASSISTANT_GUI, "ChatPage", "on_open_session"),
            "ChatPage.on_open_session missing — Sessions button broken",
        )

    def test_assistant_chat_page_instantiates(self) -> None:
        try:
            from PySide6.QtWidgets import QApplication
        except ImportError:
            self.skipTest("PySide6 not installed")
        app = QApplication.instance() or QApplication([])  # noqa: F841
        from ncc_assistant.config import Settings
        from ncc_assistant.gui import ChatPage, ConfirmBridge
        from ncc_assistant.session import ChatSession

        confirm = ConfirmBridge()
        session = ChatSession.create(
            Settings.from_env(client_mode="chat"),
            interactive_auth=False,
            refresh_models=False,
        )
        page = ChatPage(session, confirm)
        self.assertTrue(callable(page.on_confirm_request))

    def test_all_domain_pages_create_widget(self) -> None:
        try:
            from PySide6.QtWidgets import QApplication, QWidget
        except ImportError:
            self.skipTest("PySide6 not installed")
        app = QApplication.instance() or QApplication([])  # noqa: F841
        pages = _discover_page_files()
        self.assertTrue(pages, "expected ui/gui/page.py files under nixos/")
        failures: list[str] = []
        for path in pages:
            rel = path.relative_to(REPO)
            try:
                mod = _load_page_module(path)
                create = getattr(mod, "create_page", None)
                if not callable(create):
                    failures.append(f"{rel}: missing create_page()")
                    continue
                widget = create()
                if not isinstance(widget, QWidget):
                    failures.append(f"{rel}: create_page() did not return QWidget")
            except Exception as exc:
                failures.append(f"{rel}: {type(exc).__name__}: {exc}")
        if failures:
            self.fail("Domain page smoke failures:\n" + "\n".join(failures))


if __name__ == "__main__":
    raise SystemExit(unittest.main(verbosity=2))
