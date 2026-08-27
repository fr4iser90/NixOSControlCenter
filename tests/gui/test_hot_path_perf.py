#!/usr/bin/env python3
"""Hot-path perf guards for ncc_gui (see doc/PERFORMANCE.md).

AST + pure unit tests — no live rebuild / HTTP. Activity tests mock PySide6
so they run without a Qt env.
"""

from __future__ import annotations

import ast
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock

GUI_PY = Path(__file__).resolve().parents[2] / "nixos/core/management/gui-engine/python"
assert (GUI_PY / "ncc_gui" / "scaffold.py").is_file(), GUI_PY
sys.path.insert(0, str(GUI_PY))


def _fn_source(path: Path, name: str) -> str:
    text = path.read_text(encoding="utf-8")
    tree = ast.parse(text)
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == name:
            src = ast.get_source_segment(text, node)
            if src is None:
                raise AssertionError(f"no source for {name}")
            return src
    raise AssertionError(f"{name} not found in {path}")


class SoftGenerationHotPathTests(unittest.TestCase):
    def test_scaffold_soft_skips_chrome_shell_and_guards_standalone(self) -> None:
        src = _fn_source(GUI_PY / "ncc_gui" / "scaffold.py", "_on_soft_generation")
        self.assertIn("_chrome_shell_ancestor", src)
        self.assertIn("isVisible()", src)
        self.assertIn("reload", src)
        self.assertNotIn("run_ncc(", src)
        self.assertNotIn("subprocess", src)

    def test_shell_soft_generation_recreates_document_without_ssh(self) -> None:
        src = _fn_source(GUI_PY / "ncc_gui" / "shell.py", "_on_soft_generation")
        self.assertNotIn("probe", src.lower())
        self.assertNotIn("ssh", src.lower())
        self.assertNotIn("run_ncc", src)
        self.assertIn("refresh_catalog", src)
        self.assertIn("_mount_domain", src)
        self.assertIn("force=True", src)
        self.assertIn("_drop_sticky", src)


class ChromeDocumentModelTests(unittest.TestCase):
    def test_shell_is_chrome_document_not_page_stack(self) -> None:
        text = (GUI_PY / "ncc_gui" / "shell.py").read_text(encoding="utf-8")
        self.assertIn("_is_ncc_chrome_shell", text)
        self.assertIn("_mount_domain", text)
        self.assertIn("STICKY_DOMAIN_IDS", text)
        self.assertNotIn("QStackedWidget", text)
        self.assertNotIn("self._pages", text)
        self.assertNotIn("_id_to_stack", text)

    def test_shell_state_sticky_ids(self) -> None:
        # shell_state has no Qt dependency
        from ncc_gui.shell_state import STICKY_DOMAIN_IDS, ShellChromeState

        self.assertEqual(STICKY_DOMAIN_IDS, frozenset({"ai", "ssh"}))
        st = ShellChromeState()
        self.assertTrue(hasattr(st, "refresh_catalog"))
        self.assertTrue(hasattr(st, "current_domain_id"))


class ActivityCapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if "PySide6" not in sys.modules:
            sys.modules["PySide6"] = MagicMock()
            sys.modules["PySide6.QtCore"] = MagicMock()
            sys.modules["PySide6.QtWidgets"] = MagicMock()
        import ncc_gui.reload as reload  # noqa: WPS433

        cls.reload = reload

    def test_save_and_load_truncate_to_max(self) -> None:
        reload = self.reload
        with tempfile.TemporaryDirectory() as tmp:
            reload.ACTIVITY_DIR = Path(tmp)
            key = "perf-test-page"
            huge = "x" * (reload.ACTIVITY_MAX_CHARS + 50_000)
            reload.save_activity(key, huge)
            loaded = reload.load_activity(key)
            self.assertEqual(len(loaded), reload.ACTIVITY_MAX_CHARS)
            self.assertTrue(loaded.endswith("x" * 10))

    def test_empty_key_is_noop(self) -> None:
        reload = self.reload
        with tempfile.TemporaryDirectory() as tmp:
            reload.ACTIVITY_DIR = Path(tmp)
            reload.save_activity("", "should-not-write")
            self.assertEqual(list(Path(tmp).iterdir()), [])
            self.assertEqual(reload.load_activity(""), "")


class TargetConnectHotPathTests(unittest.TestCase):
    def test_combo_index_change_only_sets_candidate(self) -> None:
        """Selecting a host must not Connect/probe (PERFORMANCE.md)."""
        src = _fn_source(GUI_PY / "ncc_gui" / "target_bar.py", "_on_index")
        self.assertIn("set_candidate", src)
        self.assertNotIn("connect_target", src)
        self.assertNotIn("probe", src.lower())


if __name__ == "__main__":
    unittest.main()
