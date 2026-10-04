#!/usr/bin/env python3
"""Phase 32 companion shell UX wiring (no display)."""

from __future__ import annotations

import ast
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))


class CompanionShellAstTests(unittest.TestCase):
    def test_session_picker_not_tab_strip(self) -> None:
        text = (ROOT / "ncc_assistant" / "companion.py").read_text(encoding="utf-8")
        self.assertIn("session_btn", text)
        self.assertIn("_rebuild_session_menu", text)
        self.assertIn("_rename_session", text)
        self.assertIn("title_locked", text)
        self.assertNotIn("tabs_row", text)
        self.assertNotIn("_rebuild_tabs", text)

    def test_geometry_persist(self) -> None:
        text = (ROOT / "ncc_assistant" / "companion.py").read_text(encoding="utf-8")
        self.assertIn("_restore_geometry", text)
        self.assertIn("_save_geometry", text)
        self.assertIn("QSizeGrip", text)
        self.assertIn("saveGeometry", text)

    def test_workspace_and_panels(self) -> None:
        text = (ROOT / "ncc_assistant" / "companion.py").read_text(encoding="utf-8")
        self.assertIn("PANEL_TOOLS", text)
        self.assertIn("PANEL_MCP", text)
        self.assertIn("PANEL_WORKSPACES", text)
        self.assertIn("PANEL_TEMPLATES", text)
        self.assertIn("workspace_combo", text)
        self.assertIn("_run_template", text)
        self.assertIn("_CompanionTemplateWorker", text)
        self.assertIn("workspace_id", text)

    def test_marketplace_mcp_helpers(self) -> None:
        path = ROOT / "ncc_assistant" / "marketplace.py"
        tree = ast.parse(path.read_text(encoding="utf-8"))
        names = {
            n.name
            for n in tree.body
            if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))
        }
        self.assertIn("list_installed_mcp", names)
        self.assertIn("set_mcp_enabled", names)
        self.assertIn("remove_mcp_server", names)

    def test_preferences_workspace(self) -> None:
        path = ROOT / "ncc_assistant" / "preferences.py"
        text = path.read_text(encoding="utf-8")
        self.assertIn("get_active_workspace_id", text)
        self.assertIn("set_active_workspace_id", text)


if __name__ == "__main__":
    unittest.main()
