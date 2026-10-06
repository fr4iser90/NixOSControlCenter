#!/usr/bin/env python3
"""Hard gate: CompanionWindow must construct (catches NameError / layout typos).

Regression: leftover ``body.addWidget(...)`` after sidebar refactor crashed
``ncc ai companion`` at runtime while AST string checks still passed.

  python3 tests/gui/test_companion_window_smoke.py
"""

from __future__ import annotations

import ast
import builtins
import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSISTANT_PY = REPO / "nixos/modules/specialized/ncc-assistant/python"
COMPANION = ASSISTANT_PY / "ncc_assistant" / "companion.py"


def _companion_init_undefined_names() -> list[str]:
    """Return bare Name loads in CompanionWindow.__init__ that are never bound."""
    tree = ast.parse(COMPANION.read_text(encoding="utf-8"), filename=str(COMPANION))
    module_names: set[str] = set()
    init: ast.FunctionDef | None = None
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            module_names.add(node.name)
        elif isinstance(node, (ast.Assign, ast.AnnAssign)):
            targets = (
                node.targets
                if isinstance(node, ast.Assign)
                else ([node.target] if node.target is not None else [])
            )
            for t in targets:
                if isinstance(t, ast.Name):
                    module_names.add(t.id)
        elif isinstance(node, ast.Import):
            for alias in node.names:
                module_names.add(alias.asname or alias.name.split(".")[0])
        elif isinstance(node, ast.ImportFrom):
            for alias in node.names:
                module_names.add(alias.asname or alias.name)
        if isinstance(node, ast.ClassDef) and node.name == "CompanionWindow":
            for item in node.body:
                if isinstance(item, ast.FunctionDef) and item.name == "__init__":
                    init = item
    if init is None:
        return ["CompanionWindow.__init__ missing"]

    bound: set[str] = {"self"}
    for a in init.args.args + init.args.kwonlyargs:
        bound.add(a.arg)
    if init.args.vararg:
        bound.add(init.args.vararg.arg)
    if init.args.kwarg:
        bound.add(init.args.kwarg.arg)

    builtin_names = set(dir(builtins))
    undefined: list[str] = []

    class Walker(ast.NodeVisitor):
        def visit_Name(self, node: ast.Name) -> None:  # noqa: N802
            if isinstance(node.ctx, ast.Store):
                bound.add(node.id)
            elif isinstance(node.ctx, ast.Load):
                if (
                    node.id not in bound
                    and node.id not in module_names
                    and node.id not in builtin_names
                    and not node.id.isupper()  # PANEL_*, STATE_* constants
                ):
                    undefined.append(node.id)
            self.generic_visit(node)

        def visit_Attribute(self, node: ast.Attribute) -> None:  # noqa: N802
            # Only walk value; attribute names are not locals.
            self.visit(node.value)

        def visit_FunctionDef(self, node: ast.FunctionDef) -> None:  # noqa: N802
            # Nested defs (e.g. lambdas' bodies handled separately); skip nested
            # function bodies for binding scope — but visit defaults.
            for d in node.args.defaults + node.args.kw_defaults:
                if d is not None:
                    self.visit(d)
            # Do not walk nested function body (different scope).

        def visit_Lambda(self, node: ast.Lambda) -> None:  # noqa: N802
            for d in node.args.defaults + node.args.kw_defaults:
                if d is not None:
                    self.visit(d)
            # Skip lambda body — closes over outer names; false positives likely.

        def visit_ListComp(self, node: ast.ListComp) -> None:  # noqa: N802
            pass

        def visit_SetComp(self, node: ast.SetComp) -> None:  # noqa: N802
            pass

        def visit_DictComp(self, node: ast.DictComp) -> None:  # noqa: N802
            pass

        def visit_GeneratorExp(self, node: ast.GeneratorExp) -> None:  # noqa: N802
            pass

    Walker().visit(init)
    # Dedupe while preserving order
    seen: set[str] = set()
    out: list[str] = []
    for n in undefined:
        if n not in seen:
            seen.add(n)
            out.append(n)
    return out


class CompanionWindowSmoke(unittest.TestCase):
    def test_init_has_no_undefined_locals(self) -> None:
        bad = _companion_init_undefined_names()
        self.assertEqual(
            bad,
            [],
            f"CompanionWindow.__init__ references unbound names: {bad}",
        )

    def test_constructs_offscreen(self) -> None:
        try:
            from PySide6.QtWidgets import QApplication
        except ImportError:
            self.skipTest("PySide6 not available")

        for p in (str(ASSISTANT_PY),):
            if p not in sys.path:
                sys.path.insert(0, p)

        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        tmp = tempfile.mkdtemp(prefix="ncc-companion-smoke-")
        os.environ["XDG_CONFIG_HOME"] = tmp

        app = QApplication.instance() or QApplication([])
        from ncc_assistant.companion import AvatarCanvas, CompanionWindow

        win = CompanionWindow()
        try:
            self.assertIsInstance(win.avatar, AvatarCanvas)
            self.assertEqual(win.avatar.width(), 160)
            self.assertEqual(win.avatar.height(), 160)
            self.assertTrue(hasattr(win, "panel"))
            self.assertTrue(hasattr(win, "sidebar"))
            self.assertEqual(win.sidebar.width(), 52)
            # Avatar under main header — not parented to the icon rail
            self.assertIs(win.avatar.parentWidget(), win.panel)
            self.assertTrue(hasattr(win, "rename_btn"))
            self.assertTrue(hasattr(win, "new_chat_btn"))
            self.assertEqual(win.rename_btn.text(), "Rename")
            self.assertEqual(win.new_chat_btn.text(), "New")
            # Sidebar icons must not carry QMenus (session switcher is elsewhere)
            for btn in win.sidebar.findChildren(type(win._chat_nav_btn)):
                self.assertTrue(btn.menu() is None, btn.toolTip())
        finally:
            win.close()
            app.processEvents()


if __name__ == "__main__":
    unittest.main()
