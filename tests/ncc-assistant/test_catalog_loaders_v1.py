#!/usr/bin/env python3
"""Witnesses for the two catalog loaders — the files that break first on a data move.

``playbooks`` and ``eval_harness`` both resolve their JSON through ``data_root()``: the module
``data/`` in a checkout, ``NCC_DATA_ROOT`` in a packaged build. Neither one degrades loudly
when the JSON stops resolving — the loader swallows the failure and answers an empty list, so
a plan that moves a catalog (or renames its root env var) is green on every existing check
while the feature silently answers "no playbooks".

These tests pin the observable contract (names, sources, precedence) and the data-root
placement itself (``test_*_come_from_the_data_root``) — that pair is what a loader rewrite
cannot pass by accident: ``data/`` holds the catalogs and no importable package does.

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
from core.store.paths import data_root, playbooks_dir  # noqa: E402
from core.catalogs.playbooks import (  # noqa: E402
    Playbook,
    delete_user_playbook,
    get_playbook,
    list_playbooks,
    save_user_playbook,
)

BUILTIN_PLAYBOOKS = {
    "disk-nix-gc-advisor",
    "health-report",
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


class PlaybookLoaderTests(unittest.TestCase):
    def test_shipped_playbooks_are_the_loaded_ones(self) -> None:
        loaded = {pb.name for pb in list_playbooks()}
        self.assertEqual(loaded, BUILTIN_PLAYBOOKS)

    def test_every_shipped_json_file_actually_loaded(self) -> None:
        """A JSON file the loader cannot read is invisible, not an error — so compare sets."""
        shipped = {
            path.stem for path in (ROOT / "data" / "playbooks").glob("*.json")
        }
        self.assertEqual({pb.name for pb in list_playbooks()}, shipped)
        self.assertTrue(shipped, "no builtin playbooks shipped at all")

    def test_builtins_are_marked_builtin_and_carry_a_goal(self) -> None:
        for pb in list_playbooks():
            self.assertEqual(pb.source, "builtin", pb.name)
            self.assertTrue(pb.goal.strip(), f"{pb.name} has no goal to run")
            self.assertIsInstance(pb.dry_run, bool, pb.name)

    def test_get_playbook_resolves_and_rejects(self) -> None:
        pb = get_playbook("health-report")
        self.assertIsNotNone(pb)
        self.assertEqual(pb.name, "health-report")
        self.assertIsNone(get_playbook("does-not-exist"))

    def test_user_playbook_of_the_same_name_wins(self) -> None:
        """Builtin first in the list, user last in the dict — the user copy must be the answer."""
        name = "health-report"
        path = save_user_playbook(
            Playbook(name=name, description="operator copy", goal="operator goal")
        )
        try:
            pb = get_playbook(name)
            self.assertIsNotNone(pb)
            self.assertEqual(pb.source, "user")
            self.assertEqual(pb.goal, "operator goal")
            # Still one entry per name: the builtin is replaced, not appended.
            self.assertEqual(
                [p.name for p in list_playbooks()].count(name),
                1,
            )
        finally:
            self.assertTrue(delete_user_playbook(name))
        self.assertEqual(get_playbook(name).source, "builtin")

    def test_loader_only_reads_the_session_config_home(self) -> None:
        """The suite runs with a throwaway XDG home; user playbooks must resolve there."""
        save_user_playbook(Playbook(name="probe-only", description="", goal="g"))
        try:
            self.assertTrue((playbooks_dir() / "probe-only.json").is_file())
            self.assertEqual(get_playbook("probe-only").source, "user")
        finally:
            delete_user_playbook("probe-only")

    def test_builtin_playbooks_come_from_the_data_root(self) -> None:
        """The catalogs left the importable package on purpose — ``data/`` is data, not code.
        That is only safe because the loader answers for it: it resolves through
        ``data_root()`` (the module ``data/`` in a checkout, ``NCC_DATA_ROOT`` when packaged)
        and every builtin it reports names the file it really read. Pinning that provenance is
        what keeps a silent ``return []`` from passing as "no playbooks shipped"."""
        shipped = (data_root() / "playbooks").resolve()
        self.assertEqual(shipped, (ROOT / "data" / "playbooks").resolve())
        self.assertEqual(
            {item.name for item in shipped.iterdir() if item.name.endswith(".json")},
            {f"{name}.json" for name in BUILTIN_PLAYBOOKS},
        )
        for pb in list_playbooks():
            if pb.source == "builtin":
                self.assertEqual(Path(pb.path).resolve().parent, shipped, pb.name)


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
        """Top-level list is what ships today; ``{"cases": […]}`` is what the loader also
        accepts. Dropping either shape silently drops every case."""
        tmp = self.enterContext(tempfile.TemporaryDirectory(prefix="ncc-eval-"))
        flat = Path(tmp) / "flat.json"
        wrapped = Path(tmp) / "wrapped.json"
        entry = {"name": "shape", "tool": "list_modules", "checks": ["ok == true"]}
        flat.write_text(json.dumps([entry]), encoding="utf-8")
        wrapped.write_text(json.dumps({"cases": [entry]}), encoding="utf-8")
        self.assertEqual([c.name for c in load_eval_cases(flat)], ["shape"])
        self.assertEqual([c.name for c in load_eval_cases(wrapped)], ["shape"])

    def test_a_broken_explicit_file_yields_no_cases_instead_of_raising(self) -> None:
        """A malformed file the operator pointed at is *not* a missing file: the loader
        stops there and returns nothing rather than quietly answering from the packaged
        catalog. An absent path is the opposite — it falls through to the shipped cases.
        Both branches are pinned because a loader rewrite that merges them looks harmless
        and hides a broken operator catalog."""
        tmp = self.enterContext(tempfile.TemporaryDirectory(prefix="ncc-eval-"))
        broken = Path(tmp) / "broken.json"
        broken.write_text("{not json", encoding="utf-8")
        self.assertEqual(load_eval_cases(broken), [])
        self.assertEqual({c.name for c in load_eval_cases(Path(tmp) / "absent.json")}, EVAL_CASE_NAMES)

    def test_shipped_cases_come_from_the_data_root(self) -> None:
        """Same coupling as playbooks: the default path is ``<data root>/eval/*.json``, never a
        package-relative one. Proven by emptying that directory — a loader reading anywhere
        else would still answer the shipped set here and nowhere in production."""
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
