#!/usr/bin/env python3
"""Plan 07: the two notify options that had no reader.

Before: the wrapper exported NOTIFY_ON_SCHEDULE_START / NOTIFY_ON_JOB_END and schedule units
set them, but nothing in the run path read either — a control surface with no effect, and the
unit's hardcoded "1" would have outranked a host that turned notifications off.
Now: a unit run announces itself (actor=schedule only — a human session is already on screen)
and reports every terminal state, plus a schedule unit no longer overrides the host choice.
"""

from __future__ import annotations

import os
import subprocess
import sys
import unittest
from contextlib import contextmanager
from pathlib import Path
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
MODULE = REPO / "nixos" / "modules" / "specialized" / "ncc-assistant"
ROOT = MODULE / "python"
sys.path.insert(0, str(ROOT))

from ncc_assistant import agent as agent_module  # noqa: E402
from ncc_assistant import notifications  # noqa: E402
from ncc_assistant.config import Settings  # noqa: E402
from ncc_assistant.llm import LLMError  # noqa: E402
from ncc_assistant.permissions import ENV_ACTOR  # noqa: E402

CONFIG_KEYS = ("NOTIFY_ENABLE", "NOTIFY_TIMEOUT_SEC", "NOTIFY_ON_TIMEOUT")


@contextmanager
def notify_env(**overrides: str | None):
    """Run with a host-clean notify env; a None value means "unset"."""
    base = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith("NOTIFY_") and key not in CONFIG_KEYS and key != ENV_ACTOR
    }
    for key, value in overrides.items():
        if value is None:
            base.pop(key, None)
        else:
            base[key] = value
    with patch.dict(os.environ, base, clear=True):
        yield


def sent_notifications(action) -> list[list[str]]:
    """Run ``action`` with notify-send and every other subprocess call stubbed; return argv."""
    sent: list[list[str]] = []

    def fake_run(cmd, *args, **kwargs):
        if isinstance(cmd, (list, tuple)) and cmd and str(cmd[0]) == "notify-send":
            sent.append([str(part) for part in cmd])
            return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")
        return subprocess.CompletedProcess(cmd, 1, stdout="", stderr="")

    with patch.object(notifications.shutil, "which", return_value="/usr/bin/notify-send"):
        with patch.object(subprocess, "run", side_effect=fake_run):
            action()
    return sent


def _urgency(argv: list[str]) -> str:
    return argv[argv.index("--urgency") + 1]


def _title(argv: list[str]) -> str:
    """notify-send --app-name … --urgency … --expire-time … <title> [<body>]"""
    return argv[argv.index("--expire-time") + 2]


class FlagSemanticsTests(unittest.TestCase):
    def test_the_words_the_wrapper_emits(self) -> None:
        for raw, expected in (("1", True), ("true", True), ("YES", True), ("on", True),
                              ("0", False), ("false", False), ("off", False)):
            with self.subTest(raw=raw):
                with patch.dict(os.environ, {"NCC_TEST_FLAG": raw}, clear=True):
                    self.assertEqual(notifications._env_flag("NCC_TEST_FLAG", False), expected)
                    self.assertEqual(notifications._env_flag("NCC_TEST_FLAG", True), expected)

    def test_absent_or_blank_falls_back_to_the_option_default(self) -> None:
        # NOTIFY_ON_SCHEDULE_START defaults false, NOTIFY_ON_JOB_END true (options.nix).
        with patch.dict(os.environ, {}, clear=True):
            self.assertFalse(notifications._env_flag("NCC_TEST_FLAG", False))
            self.assertTrue(notifications._env_flag("NCC_TEST_FLAG", True))
        with patch.dict(os.environ, {"NCC_TEST_FLAG": "  "}, clear=True):
            self.assertTrue(notifications._env_flag("NCC_TEST_FLAG", True))


class ScheduleStartTests(unittest.TestCase):
    def test_a_human_run_stays_quiet(self) -> None:
        for actor in ("cli", "chat", ""):
            with self.subTest(actor=actor):
                with notify_env(**{ENV_ACTOR: actor, "NOTIFY_ON_SCHEDULE_START": "1"}):
                    sent = sent_notifications(lambda: notifications.notify_schedule_start("goal"))
                    self.assertEqual(sent, [], f"actor {actor!r} announced an interactive run")

    def test_off_unless_the_host_asks(self) -> None:
        with notify_env(**{ENV_ACTOR: "schedule"}):
            self.assertEqual(sent_notifications(lambda: notifications.notify_schedule_start("goal")), [])

    def test_a_unit_run_announces_itself(self) -> None:
        with notify_env(**{ENV_ACTOR: "schedule", "NOTIFY_ON_SCHEDULE_START": "1"}):
            sent = sent_notifications(lambda: notifications.notify_schedule_start("rotate the logs"))
        self.assertEqual(len(sent), 1)
        self.assertIn("NCC Assistant: Schedule started", sent[0])
        self.assertIn("rotate the logs", sent[0])
        self.assertEqual(_urgency(sent[0]), "low")

    def test_long_goals_do_not_become_notification_novels(self) -> None:
        with notify_env(**{ENV_ACTOR: "schedule", "NOTIFY_ON_SCHEDULE_START": "1"}):
            sent = sent_notifications(lambda: notifications.notify_schedule_start("x" * 900))
        self.assertLessEqual(len(sent[0][-1]), 160)


class JobEndTests(unittest.TestCase):
    def test_every_terminal_state_is_named_and_prioritised(self) -> None:
        cases = {
            "job_finished": ("Job finished", "normal"),
            "job_cancelled": ("Job cancelled", "low"),
            "job_failed": ("Job failed", "critical"),
        }
        self.assertEqual(set(cases), set(notifications.JOB_END_LABELS))
        for kind, (label, urgency) in cases.items():
            with self.subTest(kind=kind):
                with notify_env():
                    sent = sent_notifications(
                        lambda: notifications.notify_job_end(kind, "compact the store", "disk full")
                    )
                self.assertEqual(len(sent), 1)
                self.assertIn(f"NCC Assistant: {label}", sent[0])
                self.assertEqual(_urgency(sent[0]), urgency)
                self.assertIn("compact the store", sent[0][-1])
                self.assertIn("disk full", sent[0][-1])

    def test_non_terminal_events_are_not_job_ends(self) -> None:
        with notify_env():
            sent = sent_notifications(lambda: notifications.notify_job_end("step", "goal"))
            self.assertEqual(sent, [])

    def test_the_host_can_turn_it_off(self) -> None:
        with notify_env(NOTIFY_ON_JOB_END="0"):
            sent = sent_notifications(lambda: notifications.notify_job_end("job_finished", "goal"))
            self.assertEqual(sent, [])

    def test_the_kill_switch_outranks_both_options(self) -> None:
        with notify_env(**{ENV_ACTOR: "schedule", "NOTIFY_ENABLE": "0", "NOTIFY_ON_SCHEDULE_START": "1"}):
            sent = sent_notifications(lambda: (
                notifications.notify_schedule_start("goal"),
                notifications.notify_job_end("job_finished", "goal"),
            ))
            self.assertEqual(sent, [])


def _finished_iter(settings, messages, tools, cancel_event=None):
    yield {"type": "done", "message": {"content": "goal met", "tool_calls": []}}


def _failing_iter(settings, messages, tools, cancel_event=None):
    raise LLMError("endpoint refused")
    yield {}  # pragma: no cover — keeps this a generator


class RunPathTests(unittest.TestCase):
    """The interception lives in AgentRunner.run(), so every finalize path is covered once."""

    def _drive(self, *, actor="schedule", start="1", end=None, fake=_finished_iter, cancel=False):
        root = Path("/tmp/ncc-assistant-notify-test")
        env = {ENV_ACTOR: actor, "NOTIFY_ON_SCHEDULE_START": start, "XDG_CONFIG_HOME": str(root)}
        if end is not None:
            env["NOTIFY_ON_JOB_END"] = end

        def go():
            runner = agent_module.AgentRunner(
                Settings.from_env(client_mode="agent"),
                agent_module.AgentSettings(goal="tidy the store", max_steps=2),
            )
            if cancel:
                runner.cancel()
            return [event["kind"] for event in runner.run()]

        with notify_env(**env):
            with patch.object(agent_module, "iter_chat_completion", fake):
                sent = sent_notifications(go)
        return sent

    def test_a_unit_run_reports_start_and_end(self) -> None:
        sent = self._drive()
        self.assertIn("NCC Assistant: Schedule started", sent[0])
        self.assertIn("NCC Assistant: Job finished", sent[-1])
        self.assertIn("tidy the store", sent[-1][-1])

    def test_a_human_run_only_reports_the_end(self) -> None:
        sent = self._drive(actor="cli", start="1")
        self.assertEqual([_title(argv) for argv in sent], ["NCC Assistant: Job finished"])

    def test_the_host_end_flag_reaches_the_run(self) -> None:
        self.assertEqual(self._drive(start=None, end="0"), [])

    def test_cancelled_is_reported_as_cancelled(self) -> None:
        sent = self._drive(cancel=True)
        self.assertEqual(_title(sent[-1]), "NCC Assistant: Job cancelled")
        self.assertEqual(_urgency(sent[-1]), "low")

    def test_a_failed_run_is_critical(self) -> None:
        sent = self._drive(fake=_failing_iter)
        self.assertEqual(_title(sent[-1]), "NCC Assistant: Job failed")
        self.assertEqual(_urgency(sent[-1]), "critical")
        self.assertIn("endpoint refused", sent[-1][-1])


class WiringTests(unittest.TestCase):
    def test_the_wrapper_still_exports_both_as_host_defaults(self) -> None:
        text = (MODULE / "package.nix").read_text(encoding="utf-8")
        self.assertIn('export NOTIFY_ON_SCHEDULE_START="${if (cfg.agent.notifications.notifyOnScheduleStart or false)', text)
        self.assertIn('export NOTIFY_ON_JOB_END="${if (cfg.agent.notifications.notifyOnJobEnd or true)', text)

    def test_no_schedule_unit_outranks_the_host(self) -> None:
        """A unit value wins over the wrapper, so only the host may state this preference."""
        text = (MODULE / "schedules.nix").read_text(encoding="utf-8")
        self.assertNotIn("NOTIFY_ON_JOB_END", text)
        self.assertNotIn("NOTIFY_ON_SCHEDULE_START", text)

    def test_both_options_are_still_documented(self) -> None:
        text = (MODULE / "options.nix").read_text(encoding="utf-8")
        self.assertIn("notifyOnScheduleStart = mkOption", text)
        self.assertIn("notifyOnJobEnd = mkOption", text)

    def test_the_probe_path_announces_too(self) -> None:
        """daily-disk-probe runs no AgentRunner, so it needs its own start call."""
        cli = (ROOT / "ncc_assistant" / "cli.py").read_text(encoding="utf-8")
        probe = cli.split("def _cmd_probe_disk", 1)[1].split("\ndef ", 1)[0]
        self.assertIn("notify_schedule_start(", probe)


if __name__ == "__main__":
    unittest.main()
