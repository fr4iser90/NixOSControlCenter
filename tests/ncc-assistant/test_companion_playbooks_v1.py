#!/usr/bin/env python3
"""Witnesses for the companion's Playbooks panel — the row that starts a scoped run.

The panel is a click that starts an agent, so the only claim worth defending is the one printed
on the row: that the run happens at the scope the playbook declares. That scope is enforced
inside ``AgentRunner`` and nowhere else — ``HarnessBackend.send()`` takes a goal string and no
profile, and an external backend never reaches ``create_job``. So the safety of this feature is
the *absence* of a harness branch in ``_CompanionPlaybookWorker``, and an absence is exactly what
a test that only checks "the panel lists playbooks" would leave unprotected: adding a chip-driven
``get_harness(...)`` path later would look like a feature and quietly turn ``read-only`` into a
label. Hence the AST checks below, on source, not on behaviour.

PySide6 is not available to this suite (the Qt surfaces are gated separately), so the wiring is
read out of the AST and the enforcement half is tested for real, without Qt, through
``resolve_profile`` — the same call ``AgentRunner`` makes.

No network, no Nix, no Qt.
"""

from __future__ import annotations

import ast
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant"
sys.path.insert(0, str(ROOT))

COMPANION = ROOT / "companion" / "window.py"
PLAYBOOK_FILE = ROOT / "data" / "playbooks" / "project-drift-audit.json"


def _source_tree() -> ast.Module:
    return ast.parse(COMPANION.read_text(encoding="utf-8"), filename=str(COMPANION))


def _class_node(tree: ast.Module, name: str) -> ast.ClassDef:
    for node in tree.body:
        if isinstance(node, ast.ClassDef) and node.name == name:
            return node
    raise AssertionError(f"{name} is not a top-level class in companion/window.py")


def _function_node(owner: ast.AST, name: str) -> ast.FunctionDef:
    for node in ast.walk(owner):
        if isinstance(node, ast.FunctionDef) and node.name == name:
            return node
    raise AssertionError(f"{name} not found")


def _called_names(node: ast.AST) -> set[str]:
    """Every callable name invoked inside ``node``, dotted tails normalised to their last part."""
    found: set[str] = set()
    for call in ast.walk(node):
        if not isinstance(call, ast.Call):
            continue
        fn = call.func
        if isinstance(fn, ast.Name):
            found.add(fn.id)
        elif isinstance(fn, ast.Attribute):
            found.add(fn.attr)
    return found


class PlaybookRailTests(unittest.TestCase):
    """The panel has to be reachable from the rail and dispatch to a real runner."""

    def test_playbooks_is_a_known_panel_key(self) -> None:
        consts: dict[str, str] = {}
        for node in _source_tree().body:
            if not isinstance(node, ast.Assign) or not isinstance(node.value, ast.Constant):
                continue
            if not isinstance(node.value.value, str):
                continue
            for target in node.targets:
                if isinstance(target, ast.Name):
                    consts[target.id] = node.value.value
        self.assertEqual(consts.get("PANEL_PLAYBOOKS"), "playbooks")
        # The rail keys are one flat namespace: a duplicate value would light two panels at once.
        self.assertEqual(len(consts), len(set(consts.values())), "duplicate PANEL_* value")

    def test_the_rail_builds_a_button_for_it_in_the_work_group(self) -> None:
        """An icon in the Capabilities group would say "toggle a tool" instead of "run this"."""
        init = _function_node(_class_node(_source_tree(), "CompanionWindow"), "__init__")
        work_loop: ast.For | None = None
        for node in ast.walk(init):
            if not isinstance(node, ast.For) or not isinstance(node.iter, ast.Tuple):
                continue
            keys = {
                elt.elts[0].id
                for elt in node.iter.elts
                if isinstance(elt, ast.Tuple) and elt.elts and isinstance(elt.elts[0], ast.Name)
            }
            if {"PANEL_TEMPLATES", "PANEL_CRON", "PANEL_JOBS"} <= keys:
                work_loop = node
                break
        self.assertIsNotNone(work_loop, "the Work rail group was renamed — this check must follow")
        assert work_loop is not None and isinstance(work_loop.iter, ast.Tuple)
        keys = {
            elt.elts[0].id
            for elt in work_loop.iter.elts
            if isinstance(elt, ast.Tuple) and elt.elts and isinstance(elt.elts[0], ast.Name)
        }
        self.assertIn("PANEL_PLAYBOOKS", keys)

    def test_fill_panel_lists_playbooks_with_their_scope(self) -> None:
        fill = _function_node(_class_node(_source_tree(), "CompanionWindow"), "_fill_panel")
        text = ast.get_source_segment(COMPANION.read_text(encoding="utf-8"), fill) or ""
        branch = text.split("PANEL_PLAYBOOKS:", 1)
        self.assertEqual(len(branch), 2, "_fill_panel has no Playbooks branch")
        body = branch[1].split("elif key ==", 1)[0]
        self.assertIn("list_playbooks", body)
        # A row without its scope would let an operator start a writing run by name alone.
        self.assertIn("dry_run", body)
        self.assertIn("profile", body)
        self.assertIn('("playbook"', body)
        # Both dead ends answer: an empty catalog and a failing loader must not read as "nothing here".
        self.assertIn('addItem("(no playbooks)")', body)
        self.assertIn("(error: {exc})", body)

    def test_a_click_dispatches_to_the_playbook_runner(self) -> None:
        on_item = _function_node(
            _class_node(_source_tree(), "CompanionWindow"), "_on_panel_item"
        )
        text = ast.get_source_segment(COMPANION.read_text(encoding="utf-8"), on_item) or ""
        self.assertIn('kind == "playbook"', text)
        self.assertIn("self._run_playbook(", text)


class PlaybookRunTests(unittest.TestCase):
    """The run must be native, bounded, and loud about a playbook that cannot run."""

    def test_the_worker_calls_the_runner_and_never_a_harness(self) -> None:
        """The capability claim: no code path from a playbook to a profile-blind backend."""
        worker = _class_node(_source_tree(), "_CompanionPlaybookWorker")
        run = _function_node(worker, "run")
        called = _called_names(run)
        self.assertIn("run_agent", called)
        for forbidden in ("get_harness", "resolve_harness_name", "available_harnesses"):
            self.assertNotIn(
                forbidden,
                called,
                f"{forbidden}() in the playbook worker: the run could leave the runner that "
                "enforces profile and dry_run, making the printed scope a label",
            )

    def test_the_worker_passes_the_playbooks_own_scope(self) -> None:
        run = _function_node(_class_node(_source_tree(), "_CompanionPlaybookWorker"), "run")
        kwargs = {
            kw.arg
            for call in ast.walk(run)
            if isinstance(call, ast.Call)
            for kw in call.keywords
        }
        for required in ("profile", "dry_run", "playbook", "max_steps"):
            self.assertIn(required, kwargs, f"run_agent(...) is missing {required}= ")

    def test_the_run_reports_the_scope_it_started_with(self) -> None:
        """An operator watching the chat must be able to tell which scope ran, after the fact."""
        run = _function_node(_class_node(_source_tree(), "_CompanionPlaybookWorker"), "run")
        text = ast.get_source_segment(COMPANION.read_text(encoding="utf-8"), run) or ""
        self.assertIn('"kind": "status"', text)
        self.assertIn("native", text)

    def test_the_window_starts_it_without_consulting_the_harness_chip(self) -> None:
        start = _function_node(
            _class_node(_source_tree(), "CompanionWindow"), "_run_playbook"
        )
        called = _called_names(start)
        self.assertIn("_CompanionPlaybookWorker", called)
        self.assertNotIn(
            "resolve_harness_name",
            called,
            "the slot's harness chip must not be able to move a playbook off native",
        )

    def test_an_empty_goal_refuses_rather_than_running_nothing(self) -> None:
        start = _function_node(
            _class_node(_source_tree(), "CompanionWindow"), "_run_playbook"
        )
        text = ast.get_source_segment(COMPANION.read_text(encoding="utf-8"), start) or ""
        self.assertIn("goal.strip()", text)
        self.assertIn("QMessageBox", text)
        self.assertIn("if slot.busy", text)


class DriftPlaybookScopeTests(unittest.TestCase):
    """The scope the row prints is the scope the runtime enforces — tested, not asserted."""

    def test_the_shipped_playbook_declares_read_only_and_dry_run(self) -> None:
        import json

        data = json.loads(PLAYBOOK_FILE.read_text(encoding="utf-8"))
        self.assertEqual(data["profile"], "read-only")
        self.assertTrue(data["dry_run"])

    def test_read_only_denies_the_writing_tools_it_promises_to_denies(self) -> None:
        """Same call AgentRunner makes, so the panel cannot promise more than the runtime holds."""
        from core.policy.profiles import resolve_profile

        profile = resolve_profile("read-only")
        self.assertFalse(profile.allow_write, "read-only must not allow writes")
        self.assertFalse(profile.allow_rebuild)
        self.assertFalse(profile.allow_shell)

    def test_a_run_without_a_step_budget_stays_unlimited(self) -> None:
        """The playbook caps nothing; the companion must not invent a cap either."""
        import json

        from core.store.config import UNLIMITED, is_unlimited

        data = json.loads(PLAYBOOK_FILE.read_text(encoding="utf-8"))
        declared = data.get("max_steps")
        self.assertIsNone(declared, "the drift audit must not carry a step cap")
        # What the worker computes: `pb.max_steps or settings.agent_max_steps`.
        self.assertTrue(is_unlimited(declared or UNLIMITED))


if __name__ == "__main__":
    unittest.main()
