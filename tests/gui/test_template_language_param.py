#!/usr/bin/env python3
"""Hard gate: the agent-template modal shows a Language dropdown defaulting to English.

The param layer alone is not enough proof — a doc writer whose dropdown lands after the
multi-select repository list, or whose combo does not carry the default, still reaches the
agent with the wrong language.

  python3 tests/gui/test_template_language_param.py
"""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASSISTANT_PY = REPO / "nixos/modules/specialized/ncc-assistant/python"

OPTIONS = ["English", "Deutsch", "Auto (keep file)"]
# One from each doc-writing family: maintainer, creator, legal stub, scheduled job.
TEMPLATES = ("agents-md-maintainer", "agents-md-creator", "changelog-creator", "impressum-creator")


class TemplateLanguageDropdownSmoke(unittest.TestCase):
    def setUp(self) -> None:
        try:
            from PySide6.QtWidgets import QApplication, QComboBox
        except ImportError:
            self.skipTest("PySide6 not available")
        self.QComboBox = QComboBox
        if str(ASSISTANT_PY) not in sys.path:
            sys.path.insert(0, str(ASSISTANT_PY))
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        os.environ["XDG_CONFIG_HOME"] = tempfile.mkdtemp(prefix="ncc-tmpl-lang-")
        self.app = QApplication.instance() or QApplication([])

        from ncc_assistant.agent_templates import get_agent_template, render_goal

        self.render_goal = render_goal

        def tmpl(tid: str):
            t = get_agent_template(tid)
            self.assertIsNotNone(t, tid)
            assert t is not None
            return t

        self.get = tmpl

    def _dialog(self, tid: str):
        from ncc_assistant.templates_ui import TemplateConfigureDialog

        dlg = TemplateConfigureDialog(tid)
        self.addCleanup(dlg.deleteLater)
        return dlg

    def test_dropdown_carries_every_choice_and_starts_on_english(self) -> None:
        for tid in TEMPLATES:
            with self.subTest(tid):
                dlg = self._dialog(tid)
                _param, widget = dlg._fields["outputLanguage"]
                self.assertIsInstance(widget, self.QComboBox)
                self.assertEqual([widget.itemText(i) for i in range(widget.count())], OPTIONS)
                self.assertEqual(widget.currentData(), "English")

    def test_dropdown_sits_before_the_repository_list(self) -> None:
        # The workspace multi-select is long; a Language row after it reads as an afterthought.
        for tid in TEMPLATES:
            with self.subTest(tid):
                dlg = self._dialog(tid)
                order = list(dlg._fields)
                self.assertLess(order.index("outputLanguage"), order.index("repositories"))

    def test_picking_a_language_reaches_the_rendered_prompt(self) -> None:
        tmpl = self.get("agents-md-maintainer")
        dlg = self._dialog("agents-md-maintainer")
        _param, widget = dlg._fields["outputLanguage"]
        idx = widget.findData("Deutsch")
        self.assertGreaterEqual(idx, 0)
        widget.setCurrentIndex(idx)
        params = dlg._collect_params()
        self.assertEqual(params["outputLanguage"], "Deutsch")
        self.assertIn("Write and summarise in Deutsch.", self.render_goal(tmpl, params))

    def test_editing_a_saved_instance_restores_its_language(self) -> None:
        from ncc_assistant.templates_ui import TemplateConfigureDialog

        class _Inst:
            params = {"outputLanguage": "Deutsch", "checkFrequency": "weekly", "timezone": "UTC"}
            model = None
            enabled_schedule = False

        dlg = TemplateConfigureDialog("agents-md-maintainer", instance=_Inst())
        self.addCleanup(dlg.deleteLater)
        _p, combo = dlg._fields["outputLanguage"]
        self.assertEqual(combo.currentData(), "Deutsch")


if __name__ == "__main__":
    unittest.main()
