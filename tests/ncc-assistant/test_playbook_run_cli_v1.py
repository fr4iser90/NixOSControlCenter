"""Witnesses for ``playbook run`` — the command the operator starts a playbook with.

``_cmd_playbook_run`` builds the ``argparse.Namespace`` for ``_cmd_agent_run`` **by hand** instead
of letting argparse fill it. That is a coupling no import check can see: the moment the agent
command reads one more attribute directly off its namespace, the playbook path raises
``AttributeError`` deep inside that function — for every playbook, on the first run, with a
traceback pointing away from the line that caused it. This was not hypothetical: ``confirm`` was
read at ``cli.py:102`` and the hand-built namespace carried five fields, so
``playbook run <anything>`` died before reaching the model.

So the check here is derived rather than listed. It reads the source of ``_cmd_agent_run``,
collects every ``args.<name>`` it touches without a ``getattr`` default, and requires the
namespace produced from a real playbook to supply each one. A future direct read that the
playbook path forgets fails this test instead of failing the operator's run; adding the attribute
to the namespace without needing it stays harmless on purpose, since defaults are what argparse
would have provided anyway.

Nothing here runs a model: ``_cmd_agent_run`` is replaced by a recorder, so the assertions are
about the hand-off, not about a network answer.

No network, no Nix, no PySide6.
"""

from __future__ import annotations

import argparse
import inspect
import re
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "nixos/modules/specialized/ncc-assistant"
sys.path.insert(0, str(ROOT))

import cli.cli as cli_module  # noqa: E402

# ``args.goal`` is a read; ``getattr(args, "grant", ())`` is a guarded read and needs nothing.
DIRECT_READ = re.compile(r"\bargs\.([a-z_][a-z0-9_]*)")


def _direct_reads(fn) -> set[str]:
    """Attribute names ``fn`` reads straight off its namespace (no getattr fallback)."""
    return set(DIRECT_READ.findall(inspect.getsource(fn)))


class PlaybookRunHandoffTests(unittest.TestCase):
    def _handoff(self, argv: list[str]) -> argparse.Namespace:
        """Run ``_cmd_playbook_run`` with the agent command recorded instead of executed."""
        captured: dict[str, argparse.Namespace] = {}
        original = cli_module._cmd_agent_run
        cli_module._cmd_agent_run = lambda run_args: captured.update(run_args=run_args) or 0
        self.addCleanup(setattr, cli_module, "_cmd_agent_run", original)
        rc = cli_module._cmd_playbook_run(argparse.Namespace(**{"name": argv[0], **argv[1]}))
        self.assertEqual(rc, 0)
        return captured["run_args"]

    def test_every_direct_attribute_of_the_agent_command_is_supplied(self) -> None:
        """The coupling this file exists for: derived from the source, not from a remembered list."""
        required = _direct_reads(cli_module._cmd_agent_run)
        self.assertIn("confirm", required, "the check is vacuous if confirm is no longer read")

        run_args = self._handoff(["health-report", {}])
        missing = sorted(name for name in required if not hasattr(run_args, name))
        self.assertEqual(
            missing,
            [],
            f"playbook run builds a namespace without {missing} — AttributeError at run time",
        )

    def test_confirm_defaults_to_none_not_a_weaker_ask(self) -> None:
        """A default of ``never`` would silently un-ask for a run the host did not authorise."""
        run_args = self._handoff(["health-report", {}])
        self.assertIsNone(run_args.confirm)

    def test_the_playbooks_own_goal_and_profile_are_carried(self) -> None:
        """The playbook is the payload; handing over an empty goal would run an empty agent."""
        run_args = self._handoff(["project-drift-audit", {}])
        self.assertEqual(run_args.playbook, "project-drift-audit")
        self.assertEqual(run_args.profile, "read-only")
        self.assertIn("portfolio_drift_report", run_args.goal)

    def test_operator_flags_reach_the_agent_command(self) -> None:
        """Flags exist on the parser only to be forwarded; a dropped one is a silently ignored order."""
        run_args = self._handoff(
            [
                "health-report",
                {
                    "dry_run": True,
                    "confirm": "always",
                    "grant": ["repo=pr"],
                    "verbose": True,
                    "harness": "native",
                },
            ]
        )
        self.assertTrue(run_args.dry_run)
        self.assertEqual(run_args.confirm, "always")
        self.assertEqual(run_args.grant, ["repo=pr"])
        self.assertTrue(run_args.verbose)
        self.assertEqual(run_args.harness, "native")

    def test_a_run_without_grants_arrives_with_an_empty_list_not_none(self) -> None:
        """``resolve_run_grant`` iterates what it gets; ``None`` is a crash in the narrowing path."""
        run_args = self._handoff(["health-report", {}])
        self.assertEqual(run_args.grant, [])


class PlaybookRunParserTests(unittest.TestCase):
    """The flags must exist on this subcommand's own parser — ``agent run`` having them proves nothing.

    ``main()`` is driven with the playbook command stubbed out: parsing has to be argparse's real
    answer, while the run itself must never start. A test that reached ``_cmd_agent_run`` would
    spend the operator's API key and depend on the network.
    """

    def _main(self, argv: list[str]) -> tuple[int, argparse.Namespace | None]:
        captured: dict[str, argparse.Namespace] = {}
        original = cli_module._cmd_playbook_run
        cli_module._cmd_playbook_run = lambda args: captured.update(args=args) or 0
        self.addCleanup(setattr, cli_module, "_cmd_playbook_run", original)
        rc = cli_module.main(["playbook", "run", *argv])
        return rc, captured.get("args")

    def test_parser_accepts_the_narrowing_flags(self) -> None:
        """An unknown flag here would reject the operator's ``--confirm`` before any policy runs."""
        rc, parsed = self._main(
            ["project-drift-audit", "--dry-run", "--confirm", "always", "--grant", "repo=pr", "-v"]
        )
        self.assertEqual(rc, 0)
        self.assertIsNotNone(parsed, "argparse never reached the playbook command")
        self.assertEqual(parsed.name, "project-drift-audit")
        self.assertTrue(parsed.dry_run)
        self.assertEqual(parsed.confirm, "always")
        self.assertEqual(parsed.grant, ["repo=pr"])
        self.assertTrue(parsed.verbose)

    def test_an_unknown_flag_is_refused_rather_than_run(self) -> None:
        with self.assertRaises(SystemExit) as caught:
            self._main(["project-drift-audit", "--not-a-flag"])
        self.assertNotEqual(caught.exception.code, 0)

    def test_a_missing_playbook_name_is_an_error_not_an_empty_run(self) -> None:
        with self.assertRaises(SystemExit):
            self._main(["--dry-run"])


if __name__ == "__main__":
    unittest.main()
