#!/usr/bin/env python3
"""Page-load gate — contract + UI-thread ms budget (gui-engine/doc/page-load.md).

* Contract: schedule → banner → async/fill (AST).
* ms budget: ``reload()`` must return within ``UI_THREAD_BUDGET_MS`` when ``ncc``
  is stubbed slow — catches freezes. Live ``ready in`` stays debug-only.
"""

from __future__ import annotations

import ast
import importlib.util
import sys
import time
import unittest
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[2]
GUI_PY = REPO / "nixos/core/management/gui-engine/python"
NIXOS = REPO / "nixos"

# UI thread may not block this long while a stubbed slow ncc is "in flight".
UI_THREAD_BUDGET_MS = 50.0
# Stub pretends ncc needs this long (must be >> budget).
_STUB_NCC_MS = 200.0

# Primary DomainPage classes that intentionally skip kit begin_load
# (own banner / timer / cache-first). Shrink — prefer DomainPage.begin_load.
_LEGACY_LOADING_UI = frozenset(
    {
        "core/management/system-manager/ui/gui/page.py",
        "modules/infrastructure/stack-manager/ui/gui/page.py",
    }
)

# Still sync ``run_ncc`` inside reload/_initial_load/_reload_body.
# New pages must use ``load_ncc_status`` / ``run_ncc_async``; shrink this set.
# modules + vm migrated to async — do not re-add.
_SYNC_NCC_IN_RELOAD_ALLOWLIST = frozenset(
    {
        "core/base/hyprland/ui/gui/page.py",
        "core/base/packages/ui/gui/page.py",  # helpers call run_ncc
        "core/base/user/ui/gui/page.py",
        "core/management/install-wizard/ui/gui/page.py",
        "modules/security/ssh-manager/client/ui/gui/page.py",
    }
)

_LOAD_METHODS = frozenset({"reload", "_initial_load", "_reload_body"})


def _rel(path: Path) -> str:
    return str(path.relative_to(NIXOS))


def _domain_page_files() -> list[Path]:
    return sorted(NIXOS.glob("**/ui/gui/page.py"))


def _class_methods(cls: ast.ClassDef) -> dict[str, ast.FunctionDef]:
    out: dict[str, ast.FunctionDef] = {}
    for item in cls.body:
        if isinstance(item, ast.FunctionDef):
            out[item.name] = item
    return out


def _init_source(text: str, init: ast.FunctionDef) -> str:
    src = ast.get_source_segment(text, init)
    return src or ""


def _calls_named(fn: ast.FunctionDef, names: frozenset[str]) -> bool:
    for node in ast.walk(fn):
        if not isinstance(node, ast.Call):
            continue
        func = node.func
        if isinstance(func, ast.Name) and func.id in names:
            return True
        if isinstance(func, ast.Attribute) and func.attr in names:
            return True
    return False


def _sync_run_ncc_calls(fn: ast.FunctionDef) -> list[str]:
    """Return sync run_ncc call forms (excludes run_ncc_async / run_ncc_root)."""
    hits: list[str] = []
    for node in ast.walk(fn):
        if not isinstance(node, ast.Call):
            continue
        func = node.func
        if isinstance(func, ast.Name) and func.id == "run_ncc":
            hits.append("run_ncc(...)")
        elif isinstance(func, ast.Attribute) and func.attr == "run_ncc":
            hits.append("self.run_ncc(...)")
    return hits


def _mounts_deferred(init_src: str) -> bool:
    """True if __init__ defers work past first paint."""
    if "schedule_load" in init_src:
        return True
    if "QTimer.singleShot(0," in init_src or "QTimer.singleShot(0 ," in init_src:
        return True
    return False


def _is_self_reload_call(node: ast.AST) -> bool:
    if not isinstance(node, ast.Call):
        return False
    if node.args or node.keywords:
        return False
    func = node.func
    return (
        isinstance(func, ast.Attribute)
        and func.attr == "reload"
        and isinstance(func.value, ast.Name)
        and func.value.id == "self"
    )


def _stmts_have_direct_reload(stmts: list[ast.stmt]) -> bool:
    """True if a statement *is* ``self.reload()`` (not inside connect/lambda)."""
    for stmt in stmts:
        if isinstance(stmt, ast.Expr) and _is_self_reload_call(stmt.value):
            return True
        if isinstance(stmt, ast.If):
            if _stmts_have_direct_reload(stmt.body) or _stmts_have_direct_reload(
                stmt.orelse
            ):
                return True
        elif isinstance(stmt, ast.Try):
            if _stmts_have_direct_reload(stmt.body):
                return True
            for h in stmt.handlers:
                if _stmts_have_direct_reload(h.body):
                    return True
            if _stmts_have_direct_reload(stmt.orelse) or _stmts_have_direct_reload(
                stmt.finalbody
            ):
                return True
        elif isinstance(stmt, (ast.With, ast.For, ast.While, ast.AsyncWith, ast.AsyncFor)):
            if _stmts_have_direct_reload(stmt.body):
                return True
            if isinstance(stmt, ast.For) and _stmts_have_direct_reload(stmt.orelse):
                return True
            if isinstance(stmt, ast.While) and _stmts_have_direct_reload(stmt.orelse):
                return True
    return False


def _has_bare_reload_in_init(init: ast.FunctionDef) -> bool:
    return _stmts_have_direct_reload(init.body)


class PageLoadKitAstTests(unittest.TestCase):
    def test_scaffold_has_load_api(self) -> None:
        text = (GUI_PY / "ncc_gui" / "scaffold.py").read_text(encoding="utf-8")
        for name in (
            "begin_load",
            "end_load",
            "schedule_load",
            "load_ncc_status",
            "abort_background_work",
            "is_loading",
            "nccLoadingBanner",
        ):
            self.assertIn(name, text, f"scaffold missing {name}")

    def test_shell_aborts_on_destroy(self) -> None:
        text = (GUI_PY / "ncc_gui" / "shell.py").read_text(encoding="utf-8")
        self.assertIn("abort_background_work", text)
        self.assertIn("def _destroy_page", text)

    def test_all_domain_pages_load_contract(self) -> None:
        """Uniform protocol for every ui/gui/page.py DomainPage."""
        checked = 0
        for path in _domain_page_files():
            rel = _rel(path)
            text = path.read_text(encoding="utf-8")
            tree = ast.parse(text)
            for node in tree.body:
                if not isinstance(node, ast.ClassDef):
                    continue
                if not node.name.endswith("Page"):
                    continue
                # Skip tiny fallbacks inside assistant factory
                if node.name.startswith("_"):
                    continue
                methods = _class_methods(node)
                init = methods.get("__init__")
                if init is None:
                    continue
                init_src = _init_source(text, init)
                load_fns = [methods[n] for n in _LOAD_METHODS if n in methods]

                # Action-only pages (no reload) — lock, etc.
                if not load_fns:
                    self.assertNotIn(
                        "self.reload()",
                        init_src.replace("schedule_load(self.reload)", ""),
                        f"{rel}: __init__ calls reload but class has no reload",
                    )
                    continue

                checked += 1

                # Mount: never sync reload in __init__ (callbacks/lambdas OK)
                self.assertFalse(
                    _has_bare_reload_in_init(init),
                    f"{rel}: __init__ calls self.reload() sync — use schedule_load",
                )

                # If __init__ kicks a load, it must be deferred
                kicks = (
                    "schedule_load" in init_src
                    or "self.reload()" in init_src
                    or "_initial_load" in init_src
                    or "_schedule_reload" in init_src
                    or "_reload_now" in init_src
                )
                if kicks:
                    self.assertTrue(
                        _mounts_deferred(init_src),
                        f"{rel}: mount load must use schedule_load or "
                        f"QTimer.singleShot(0, …)",
                    )

                # Loading UI on primary load methods
                if rel not in _LEGACY_LOADING_UI:
                    ok_ui = False
                    for fn in load_fns:
                        if _calls_named(
                            fn, frozenset({"begin_load", "load_ncc_status"})
                        ):
                            ok_ui = True
                            break
                        # reload that only forwards to a deferred scheduler
                        fn_src = ast.get_source_segment(text, fn) or ""
                        if "schedule_load" in fn_src or "_schedule_reload" in fn_src:
                            ok_ui = True
                            break
                    self.assertTrue(
                        ok_ui,
                        f"{rel}: reload/_initial_load must call begin_load or "
                        f"load_ncc_status (or add to _LEGACY_LOADING_UI with reason)",
                    )

                # Sync run_ncc inside load methods — allowlisted debt only
                if rel not in _SYNC_NCC_IN_RELOAD_ALLOWLIST:
                    for fn in load_fns:
                        hits = _sync_run_ncc_calls(fn)
                        self.assertEqual(
                            hits,
                            [],
                            f"{rel}: {fn.name} uses sync {hits} — use "
                            f"load_ncc_status / run_ncc_async, or add to "
                            f"_SYNC_NCC_IN_RELOAD_ALLOWLIST while migrating",
                        )

        self.assertGreaterEqual(
            checked, 8, "expected several DomainPage load contracts"
        )


class PageLoadRuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        ps = str(GUI_PY)
        if ps not in sys.path:
            sys.path.insert(0, ps)

    def test_begin_end_refcount(self) -> None:
        try:
            from PySide6.QtWidgets import QApplication
        except ImportError:
            self.skipTest("PySide6 not installed")
        app = QApplication.instance() or QApplication([])  # noqa: F841
        from ncc_gui.scaffold import DomainPage

        page = DomainPage("Test", "sub")
        self.assertFalse(page.is_loading)
        self.assertTrue(page._loading_banner.isHidden())
        page.begin_load("One")
        self.assertTrue(page.is_loading)
        self.assertFalse(page._loading_banner.isHidden())
        self.assertIn("One", page._loading_banner.text())
        page.begin_load("Two")
        self.assertTrue(page.is_loading)
        page.end_load()
        self.assertTrue(page.is_loading)
        page.end_load()
        self.assertFalse(page.is_loading)
        self.assertTrue(page._loading_banner.isHidden())

    def test_invoke_done_arity(self) -> None:
        try:
            from PySide6.QtWidgets import QApplication
        except ImportError:
            self.skipTest("PySide6 not installed")
        app = QApplication.instance() or QApplication([])  # noqa: F841
        from ncc_gui.scaffold import DomainPage

        page = DomainPage("Test", "")
        seen: list[tuple] = []

        def one(code: int) -> None:
            seen.append((code,))

        def two(code: int, output: str) -> None:
            seen.append((code, output))

        page._on_proc_done = one
        page._invoke_proc_done(0, "hi")
        page._on_proc_done = two
        page._invoke_proc_done(1, "out")
        self.assertEqual(seen, [(0,), (1, "out")])

    def test_abort_clears_loading_and_bumps_gen(self) -> None:
        try:
            from PySide6.QtWidgets import QApplication
        except ImportError:
            self.skipTest("PySide6 not installed")
        app = QApplication.instance() or QApplication([])  # noqa: F841
        from ncc_gui.scaffold import DomainPage

        page = DomainPage("Test", "")
        gen0 = page._load_gen
        page.begin_load("…")
        page.abort_background_work()
        self.assertFalse(page.is_loading)
        self.assertTrue(page._loading_banner.isHidden())
        self.assertGreater(page._load_gen, gen0)
        self.assertIsNone(page._proc)


class PageLoadBudgetTests(unittest.TestCase):
    """ms gate: reload must not block the UI thread (stubbed slow ncc)."""

    @classmethod
    def setUpClass(cls) -> None:
        ps = str(GUI_PY)
        if ps not in sys.path:
            sys.path.insert(0, ps)

    def _app(self) -> Any:
        try:
            from PySide6.QtWidgets import QApplication
        except ImportError:
            self.skipTest("PySide6 not installed")
        return QApplication.instance() or QApplication([])

    def _stub_slow_start(self, page: Any) -> None:
        """Replace QProcess start: keep loading; never block the caller."""

        def _start(
            program: str,
            argv: list[str] | tuple[str, ...],
            *,
            label: str,
            on_done: Any,
            env: dict[str, str] | None = None,
            activity: bool = True,
        ) -> None:
            page._on_proc_done = on_done
            page._proc_activity = activity
            page._proc_buf = ""
            # Intentionally do not call on_done here — simulates in-flight ncc.
            _ = (program, argv, label, env, _STUB_NCC_MS)

        page._start_ncc_process = _start  # type: ignore[method-assign]

    def test_kit_load_ncc_status_returns_within_budget(self) -> None:
        self._app()
        from ncc_gui.scaffold import DomainPage

        class _P(DomainPage):
            def reload(self) -> None:
                self.load_ncc_status(
                    "desktop",
                    "status",
                    label="Loading…",
                    on_result=lambda _c, _o: None,
                )

        page = _P("Budget", "")
        self._stub_slow_start(page)
        t0 = time.perf_counter()
        page.reload()
        ms = (time.perf_counter() - t0) * 1000
        self.assertLess(
            ms,
            UI_THREAD_BUDGET_MS,
            f"load_ncc_status blocked UI for {ms:.1f}ms "
            f"(budget {UI_THREAD_BUDGET_MS}ms; stub ncc {_STUB_NCC_MS}ms)",
        )
        self.assertTrue(page.is_loading)
        page.abort_background_work()

    def test_sync_reload_sleep_fails_budget(self) -> None:
        """Control: sync work in reload exceeds the ms budget (gate would catch)."""
        self._app()
        from ncc_gui.scaffold import DomainPage

        class _Sync(DomainPage):
            def reload(self) -> None:
                self.begin_load("…")
                try:
                    time.sleep(_STUB_NCC_MS / 1000.0)
                finally:
                    self.end_load()

        page = _Sync("SyncBad", "")
        t0 = time.perf_counter()
        page.reload()
        ms = (time.perf_counter() - t0) * 1000
        self.assertGreaterEqual(
            ms,
            UI_THREAD_BUDGET_MS,
            "control test broken: sync sleep should exceed budget",
        )

    def test_modules_reload_ui_thread_budget(self) -> None:
        self._app()
        path = NIXOS / "core/management/module-manager/ui/gui/page.py"
        mod_name = "ncc_modules_gui_page_budget"
        spec = importlib.util.spec_from_file_location(mod_name, path)
        assert spec is not None and spec.loader is not None
        mod = importlib.util.module_from_spec(spec)
        sys.modules[mod_name] = mod
        spec.loader.exec_module(mod)
        page = mod.ModulesPage()
        self._stub_slow_start(page)
        t0 = time.perf_counter()
        page.reload()
        ms = (time.perf_counter() - t0) * 1000
        self.assertLess(
            ms,
            UI_THREAD_BUDGET_MS,
            f"ModulesPage.reload blocked UI for {ms:.1f}ms "
            f"(budget {UI_THREAD_BUDGET_MS}ms) — sync run_ncc?",
        )
        self.assertTrue(page.is_loading)
        page.abort_background_work()


if __name__ == "__main__":
    raise SystemExit(unittest.main(verbosity=2))
