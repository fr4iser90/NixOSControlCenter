#!/usr/bin/env python3
"""Witnesses for the two catalog loaders — the files that break first on a data move.

``agent_templates`` and ``eval_harness`` both resolve their JSON through ``data_root()``: the
module ``data/`` in a checkout, ``NCC_DATA_ROOT`` in a packaged build. Neither one degrades
loudly when the JSON stops resolving — the loader swallows the failure and answers an empty
list, so a plan that moves a catalog (or renames its root env var) is green on every existing
check while the feature silently answers "no workflows".

These tests pin the observable contract (ids, sources, resolve_workflow_run) and the data-root
placement itself — that pair is what a loader rewrite cannot pass by accident: ``data/`` holds
the catalogs and no importable package does.

No network, no Nix, no PySide6.
"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant"
sys.path.insert(0, str(ROOT))

from core.catalogs.eval_harness import EvalCase, load_eval_cases  # noqa: E402
from core.store.paths import data_root, agent_templates_dir  # noqa: E402
from core.catalogs.agent_templates import (  # noqa: E402
    get_agent_template,
    list_agent_templates,
    resolve_workflow_run,
)

MIGRATED_WORKFLOWS = {
    "disk-nix-gc-advisor",
    "health-report",
    "project-drift-audit",
    "red-team-guards",
    "unused-modules-dry-run",
}
EVAL_CASE_NAMES = {
    "list_modules_ok",
    "search_knowledge_query",
    "propose_config_patch_dry",
    "apply_module_config_no_confirm_fails",
    "memory_list_ok",
}


class AgentTemplateLoaderTests(unittest.TestCase):
    def test_migrated_workflows_are_loaded(self) -> None:
        loaded = {t.id for t in list_agent_templates()}
        self.assertTrue(MIGRATED_WORKFLOWS.issubset(loaded), loaded)

    def test_every_shipped_json_file_actually_loaded(self) -> None:
        shipped = {path.stem for path in (ROOT / "data" / "agents").glob("*.json")}
        self.assertEqual({t.id for t in list_agent_templates() if t.source == "builtin"}, shipped)
        self.assertTrue(shipped, "no builtin agent templates shipped at all")

    def test_builtins_are_marked_builtin_and_resolve(self) -> None:
        for wid in MIGRATED_WORKFLOWS:
            tmpl = get_agent_template(wid)
            self.assertIsNotNone(tmpl, wid)
            self.assertEqual(tmpl.source, "builtin", wid)
            resolved = resolve_workflow_run(wid)
            self.assertIsNotNone(resolved, wid)
            self.assertTrue(str(resolved["goal"]).strip(), wid)

    def test_get_agent_template_resolves_and_rejects(self) -> None:
        tmpl = get_agent_template("health-report")
        self.assertIsNotNone(tmpl)
        self.assertEqual(tmpl.id, "health-report")
        self.assertIsNone(get_agent_template("does-not-exist"))
        self.assertIsNone(resolve_workflow_run("does-not-exist"))

    def test_user_template_of_the_same_id_wins(self) -> None:
        name = "health-report"
        user_dir = agent_templates_dir()
        path = user_dir / f"{name}.json"
        path.write_text(
            json.dumps(
                {
                    "id": name,
                    "title": "operator copy",
                    "goalTemplate": "operator goal",
                    "profile": "read-only",
                    "dryRun": True,
                }
            ),
            encoding="utf-8",
        )
        try:
            tmpl = get_agent_template(name)
            self.assertIsNotNone(tmpl)
            self.assertEqual(tmpl.source, "user")
            self.assertEqual(tmpl.goal_template, "operator goal")
            self.assertEqual([t.id for t in list_agent_templates()].count(name), 1)
        finally:
            path.unlink(missing_ok=True)
        self.assertEqual(get_agent_template(name).source, "builtin")

    def test_builtin_agents_come_from_the_data_root(self) -> None:
        shipped = (data_root() / "agents").resolve()
        self.assertEqual(shipped, (ROOT / "data" / "agents").resolve())
        self.assertTrue(
            MIGRATED_WORKFLOWS.issubset(
                {item.stem for item in shipped.iterdir() if item.suffix == ".json"}
            )
        )
        for tmpl in list_agent_templates():
            if tmpl.source == "builtin":
                self.assertEqual(Path(tmpl.path).resolve().parent, shipped, tmpl.id)


class EvalCaseLoaderTests(unittest.TestCase):
    def test_shipped_cases_are_the_loaded_ones(self) -> None:
        cases = load_eval_cases()
        self.assertEqual({c.name for c in cases}, EVAL_CASE_NAMES)

    def test_shipped_cases_all_parse(self) -> None:
        raw = json.loads(
            (ROOT / "data" / "eval" / "cases.json").read_text(encoding="utf-8")
        )
        self.assertEqual(len(load_eval_cases()), len(raw))

    def test_every_case_targets_a_tool_with_a_check(self) -> None:
        for case in load_eval_cases():
            self.assertTrue(case.tool, f"{case.name} calls no tool")
            self.assertTrue(case.checks, f"{case.name} asserts nothing")
            self.assertTrue(case.expected, f"{case.name} expects nothing")

    def test_explicit_path_beats_the_packaged_file(self) -> None:
        tmp = self.enterContext(tempfile.TemporaryDirectory(prefix="ncc-eval-"))
        path = Path(tmp) / "cases.json"
        path.write_text(
            json.dumps(
                [{"name": "explicit_only", "tool": "list_modules", "checks": ["ok == true"]}]
            ),
            encoding="utf-8",
        )
        cases = load_eval_cases(path)
        self.assertEqual([c.name for c in cases], ["explicit_only"])

    def test_both_payload_shapes_load(self) -> None:
        tmp = self.enterContext(tempfile.TemporaryDirectory(prefix="ncc-eval-"))
        flat = Path(tmp) / "flat.json"
        wrapped = Path(tmp) / "wrapped.json"
        entry = {"name": "shape", "tool": "list_modules", "checks": ["ok == true"]}
        flat.write_text(json.dumps([entry]), encoding="utf-8")
        wrapped.write_text(json.dumps({"cases": [entry]}), encoding="utf-8")
        self.assertEqual([c.name for c in load_eval_cases(flat)], ["shape"])
        self.assertEqual([c.name for c in load_eval_cases(wrapped)], ["shape"])

    def test_a_broken_explicit_file_yields_no_cases_instead_of_raising(self) -> None:
        tmp = self.enterContext(tempfile.TemporaryDirectory(prefix="ncc-eval-"))
        broken = Path(tmp) / "broken.json"
        broken.write_text("{not json", encoding="utf-8")
        self.assertEqual(load_eval_cases(broken), [])
        self.assertEqual({c.name for c in load_eval_cases(Path(tmp) / "absent.json")}, EVAL_CASE_NAMES)

    def test_shipped_cases_come_from_the_data_root(self) -> None:
        shipped = (data_root() / "eval").resolve()
        self.assertEqual(shipped, (ROOT / "data" / "eval").resolve())
        self.assertTrue((shipped / "cases.json").is_file())
        self.assertEqual({c.name for c in load_eval_cases()}, EVAL_CASE_NAMES)

    def test_case_defaults_when_optional_keys_absent(self) -> None:
        case = EvalCase.from_dict({"name": "bare", "tool": "list_modules"})
        self.assertEqual(case.kind, "invariant")
        self.assertEqual(case.args, {})
        self.assertEqual(case.checks, [])


if __name__ == "__main__":
    unittest.main()
