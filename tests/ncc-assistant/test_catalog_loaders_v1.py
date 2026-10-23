#!/usr/bin/env python3
"""Witnesses for the two catalog loaders — the files that break first on a data move.

``playbooks`` and ``eval_harness`` both resolve their JSON through the **package**
(``importlib.resources.files("ncc_assistant")`` and ``Path(__file__).parent``). Neither one
degrades loudly when the JSON stops living inside the importable package: the resources call
raises ``TypeError``/``AttributeError``, both are swallowed, and the loader returns an empty
list. A plan that moves ``playbooks/`` and ``eval/`` out of the package into ``data/`` is
therefore green on every existing check while the feature silently answers "no playbooks".

These tests pin the observable contract (names, sources, precedence) so the move has to keep
loading them, and they pin the packaged placement itself (`test_data_lives_inside_the_*`) —
that pair is what a loader rewrite cannot pass by accident.

No network, no Nix, no PySide6.
"""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from importlib import resources
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"
sys.path.insert(0, str(ROOT))

from ncc_assistant.eval_harness import EvalCase, load_eval_cases  # noqa: E402
from ncc_assistant.paths import playbooks_dir  # noqa: E402
from ncc_assistant.playbooks import (  # noqa: E402
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
            path.stem for path in (ROOT / "ncc_assistant" / "playbooks").glob("*.json")
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

    def test_data_lives_inside_the_importable_package(self) -> None:
        """`importlib.resources` only reaches files inside a package — the reason `data/`
        needs its own root env var instead of a second resources call. Red by design the
        moment the catalogs move out; that is the point, not a regression."""
        pkg_dir = resources.files("ncc_assistant") / "playbooks"
        self.assertTrue(pkg_dir.is_dir())
        self.assertEqual(
            {item.name for item in pkg_dir.iterdir() if item.name.endswith(".json")},
            {f"{name}.json" for name in BUILTIN_PLAYBOOKS},
        )


class EvalCaseLoaderTests(unittest.TestCase):
    def test_shipped_cases_are_the_loaded_ones(self) -> None:
        cases = load_eval_cases()
        self.assertEqual({c.name for c in cases}, EVAL_CASE_NAMES)

    def test_shipped_cases_all_parse(self) -> None:
        raw = json.loads(
            (ROOT / "ncc_assistant" / "eval" / "cases.json").read_text(encoding="utf-8")
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

    def test_data_lives_inside_the_importable_package(self) -> None:
        """Same coupling as playbooks: the default path is ``<package>/eval/cases.json``,
        derived from the module file — not from an env var. Red by design once `data/`
        owns the catalog; the loader has to answer for it then."""
        module_file = Path(sys.modules["ncc_assistant.eval_harness"].__file__).resolve()
        packaged = module_file.parent / "eval" / "cases.json"
        self.assertTrue(packaged.is_file())
        self.assertEqual({c.name for c in load_eval_cases()}, EVAL_CASE_NAMES)

    def test_case_defaults_when_optional_keys_absent(self) -> None:
        case = EvalCase.from_dict({"name": "bare", "tool": "list_modules"})
        self.assertEqual(case.kind, "invariant")
        self.assertEqual(case.args, {})
        self.assertEqual(case.checks, [])


if __name__ == "__main__":
    unittest.main()
