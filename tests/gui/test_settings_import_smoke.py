#!/usr/bin/env python3
"""Smoke: ncc_gui settings + domain settings.py must load / compile.

Catches mistakes like SettingsTabSpec field order (dataclass TypeError at
import) *before* system-update lands a broken GUI.

No display needed. PySide6 import is optional (skipped if missing); AST +
compileall always run.

  python3 tests/gui/test_settings_import_smoke.py
  bash tests/gui/validate-gui-python.sh
"""

from __future__ import annotations

import ast
import compileall
import py_compile
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GUI_PY = REPO / "nixos/core/management/gui-engine/python"
NCC_GUI = GUI_PY / "ncc_gui"
NIXOS = REPO / "nixos"


def _dataclass_fields(class_node: ast.ClassDef) -> list[ast.AnnAssign]:
    out: list[ast.AnnAssign] = []
    for stmt in class_node.body:
        if isinstance(stmt, ast.AnnAssign) and isinstance(stmt.target, ast.Name):
            out.append(stmt)
    return out


def _has_default(ann: ast.AnnAssign) -> bool:
    if ann.value is not None:
        return True
    # field(...) always counts as default for ordering purposes
    return False


def _check_dataclass_field_order(path: Path, class_name: str) -> None:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    for node in tree.body:
        if not isinstance(node, ast.ClassDef) or node.name != class_name:
            continue
        is_dc = any(
            (isinstance(d, ast.Name) and d.id == "dataclass")
            or (isinstance(d, ast.Attribute) and d.attr == "dataclass")
            or (
                isinstance(d, ast.Call)
                and (
                    (isinstance(d.func, ast.Name) and d.func.id == "dataclass")
                    or (isinstance(d.func, ast.Attribute) and d.func.attr == "dataclass")
                )
            )
            for d in node.decorator_list
        )
        if not is_dc:
            continue
        seen_default = False
        for ann in _dataclass_fields(node):
            name = ann.target.id  # type: ignore[union-attr]
            if _has_default(ann):
                seen_default = True
            elif seen_default:
                raise AssertionError(
                    f"{path}:{class_name}: non-default field {name!r} follows a "
                    f"default field (dataclass import will TypeError)"
                )
        return
    raise AssertionError(f"{path}: dataclass {class_name} not found")


class GuiPythonSmoke(unittest.TestCase):
    def test_settings_tab_spec_field_order(self) -> None:
        proto = NCC_GUI / "settings" / "protocol.py"
        self.assertTrue(proto.is_file(), f"missing {proto}")
        _check_dataclass_field_order(proto, "SettingsTabSpec")

    def test_compileall_ncc_gui(self) -> None:
        self.assertTrue(NCC_GUI.is_dir(), f"missing {NCC_GUI}")
        ok = compileall.compile_dir(str(NCC_GUI), quiet=1, force=True)
        self.assertTrue(ok, "compileall failed under ncc_gui/")

    def test_compile_domain_settings_py(self) -> None:
        paths = sorted(NIXOS.rglob("ui/gui/settings.py"))
        self.assertTrue(paths, "expected at least one ui/gui/settings.py")
        for p in paths:
            py_compile.compile(str(p), doraise=True)

    def test_import_settings_if_pyside(self) -> None:
        """Full import catches dataclass/runtime errors when Qt is available."""
        try:
            import PySide6  # noqa: F401
        except ImportError:
            self.skipTest("PySide6 not installed in this environment")
        sys.path.insert(0, str(GUI_PY))
        # Import chain that broke GUI: settings → dialog → discover → core_tabs → protocol
        from ncc_gui.settings.protocol import SettingsTabSpec  # noqa: WPS433
        from ncc_gui.settings import open_settings_dialog  # noqa: F401,WPS433

        def _b(_p):
            return None

        def _c(_w):
            return {}

        def _a(_d):
            return None

        spec = SettingsTabSpec(
            id="t",
            title="T",
            build=_b,
            collect=_c,
            apply=_a,
        )
        self.assertEqual(spec.order, 100)


if __name__ == "__main__":
    # Ensure PYTHONPATH for direct script runs
    if str(GUI_PY) not in sys.path:
        sys.path.insert(0, str(GUI_PY))
    raise SystemExit(unittest.main(verbosity=2))
