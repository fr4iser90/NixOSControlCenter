"""Phase 39 L8: per-schedule budgets stop a unit that keeps producing.

A schedule is a loop with no human on the other end, so the limit cannot be "is this
allowed" — it has to be "how much per day". Counters live in ``budget.json``, are keyed
by actor and repo, and are checked *before* the LLM call: a breach costs nothing.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from contextlib import ExitStack, contextmanager
from datetime import datetime, timedelta
from pathlib import Path
from unittest import mock

import pytest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant" / "python"))

from ncc_assistant import audit, budgets, cli, maintenance, paths, workflow_execute
from test_permission_ladder_v1 import _repo, grant_env
from test_run_length_budgets import _settings

BUDGET_ENV = (
    budgets.ENV_MAX_RUNS_PER_DAY,
    budgets.ENV_MAX_PRS_PER_DAY,
    budgets.ENV_MAX_DIFF_LINES,
    budgets.ENV_MAX_OPEN_AGENT_PRS,
)


@pytest.fixture(autouse=True)
def clean_budget_state():
    """One test, one counter file — and never the operator's own ``budget.json``."""
    paths.budget_file().unlink(missing_ok=True)
    # The breach audit shares the session's throwaway home, so an assertion like
    # "exactly one budget_exceeded line" only means anything on an empty log.
    audit.clear_audit()
    saved = {name: os.environ.pop(name, None) for name in BUDGET_ENV}
    yield
    paths.budget_file().unlink(missing_ok=True)
    for name in BUDGET_ENV:
        os.environ.pop(name, None)
        if saved[name] is not None:
            os.environ[name] = saved[name]


def _events(event: str) -> list[dict]:
    path = paths.audit_file()
    if not path.is_file():
        return []
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    return [r for r in rows if r.get("event") == event]


def _git_out(root: Path, *args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=root, check=True, capture_output=True, text=True
    ).stdout


def _read_state() -> dict:
    return json.loads(paths.budget_file().read_text(encoding="utf-8"))


# --- runs per day --------------------------------------------------------------------


def test_the_second_run_of_the_day_is_skipped_and_says_why():
    os.environ[budgets.ENV_MAX_RUNS_PER_DAY] = "1"
    with grant_env(repo="observe", actor="schedule:daily-audit"):
        assert budgets.check_run().allowed is True
        budgets.record_run()
        denied = budgets.check_run()

    assert denied.allowed is False and denied.code == budgets.BUDGET_RUNS
    assert "schedule:daily-audit" in denied.reason
    breach = _events("budget_exceeded")
    assert len(breach) == 1
    assert breach[0]["tool"] == budgets.BUDGET_RUNS
    assert breach[0]["actor"] == "schedule:daily-audit"
    assert breach[0]["result"] == "denied"


def test_counters_are_kept_per_actor():
    os.environ[budgets.ENV_MAX_RUNS_PER_DAY] = "1"
    with grant_env(repo="observe", actor="schedule:daily-audit"):
        budgets.record_run()
    with grant_env(repo="observe", actor="schedule:nightly"):
        assert budgets.check_run().allowed is True, "a busy schedule may not starve another"
    with grant_env(repo="observe", actor="schedule:daily-audit"):
        assert budgets.check_run().code == budgets.BUDGET_RUNS
        assert budgets.runs_today("schedule:daily-audit") == 1
        assert budgets.runs_today("schedule:nightly") == 0


def test_a_run_without_a_grant_is_a_human_and_stays_unbounded():
    os.environ[budgets.ENV_MAX_RUNS_PER_DAY] = "1"
    with grant_env():
        assert budgets.applies() is False
        for _ in range(5):
            assert budgets.check_run().allowed is True
    assert _events("budget_exceeded") == []


def test_zero_turns_a_counter_off():
    os.environ[budgets.ENV_MAX_RUNS_PER_DAY] = "0"
    with grant_env(repo="observe", actor="schedule:daily-audit"):
        for _ in range(4):
            budgets.record_run()
        assert budgets.check_run().allowed is True
        assert "maxRunsPerDay" not in budgets.summary()["limits"], "0 means off, not tiny"


def test_a_run_over_budget_never_reaches_the_job_store_or_the_llm():
    """plan-39 §5: the skip happens before anything is spent."""
    from ncc_assistant.agent import AgentRunner, AgentSettings

    os.environ[budgets.ENV_MAX_RUNS_PER_DAY] = "1"
    with mock.patch("ncc_assistant.agent.get_job_store") as store, mock.patch(
        "ncc_assistant.runtime.ToolRuntime"
    ), mock.patch.object(AgentRunner, "_check_preconditions", return_value=None), mock.patch.object(
        AgentRunner, "_run_with_lock"
    ) as locked, mock.patch("ncc_assistant.agent.AgentLock") as lock:
        with grant_env(repo="pr", actor="schedule:daily-audit"):
            budgets.record_run()
            runner = AgentRunner(_settings(), AgentSettings(goal="churn"))
            events = list(runner.run())

    skipped = [e for e in events if e.get("kind") == "skipped"]
    assert len(events) == 1 and skipped[0]["reason"] == budgets.BUDGET_RUNS
    assert skipped[0]["hint"], "the operator has to learn which knob to turn"
    locked.assert_not_called()
    lock.assert_not_called()
    store.return_value.create.assert_not_called()


# --- diff lines per run --------------------------------------------------------------


def test_a_diff_over_the_cap_is_unstaged_and_the_work_stays_local(tmp_path):
    root = _repo(tmp_path)
    (root / "big.txt").write_text("".join(f"line {i}\n" for i in range(20)), encoding="utf-8")
    os.environ[budgets.ENV_MAX_DIFF_LINES] = "5"

    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="commit", actor="schedule:dep-bump"):
            out = workflow_execute.commit_all("t", message="chore: big")

    assert out["ok"] is False and out["denied"] == budgets.BUDGET_DIFF
    assert out["committed"] is False and out["diffLines"] == 20
    assert _git_out(root, "diff", "--cached", "--numstat") == "", "the diff cap unstages"
    assert len(_git_out(root, "log", "--oneline").splitlines()) == 1, "no commit was made"
    assert "big.txt" in _git_out(root, "status", "--porcelain"), "the work is still there"
    assert _events("budget_exceeded")[0]["tool"] == budgets.BUDGET_DIFF


def test_a_small_diff_in_the_same_run_still_gets_committed(tmp_path):
    root = _repo(tmp_path)
    (root / "notes.md").write_text("work\n", encoding="utf-8")
    os.environ[budgets.ENV_MAX_DIFF_LINES] = "5"

    with mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)):
        with grant_env(repo="commit"):
            out = workflow_execute.commit_all("t", message="docs: notes")

    assert out["ok"] is True and out["committed"] is True
    assert len(_git_out(root, "log", "--oneline").splitlines()) == 2


# --- PRs per day and open agent PRs --------------------------------------------------


@contextmanager
def _publish_env(root: Path):
    """gh present, push already done — only the budget stands between us and a PR.

    The stub answers ``gh`` only and hands git to the real runner: ``_repo_key`` reads
    ``git remote get-url origin`` through ``_run``, so a stub answering every command would
    key the budget on the canned PR URL instead of the repo.
    """
    ok = {
        "ok": True,
        "cmd": ["gh"],
        "returncode": 0,
        "stdout": "https://github.com/o/r/pull/9",
        "stderr": "",
    }
    real_run = workflow_execute._run
    gh_calls: list[list[str]] = []

    def dispatch(cmd: list[str], *args, **kwargs):
        if cmd and cmd[0] == "gh":
            gh_calls.append(list(cmd))
            return dict(ok)
        return real_run(cmd, *args, **kwargs)

    run = mock.Mock(side_effect=dispatch)
    with ExitStack() as stack:
        for patcher in (
            mock.patch.object(workflow_execute.shutil, "which", return_value="/usr/bin/gh"),
            mock.patch.object(workflow_execute, "_repo_root", return_value=("t", root)),
            mock.patch.object(workflow_execute, "_run", run),
            mock.patch.object(workflow_execute, "push_branch", return_value={"ok": True}),
        ):
            stack.enter_context(patcher)
        yield gh_calls


def test_a_pr_over_the_daily_cap_is_held_after_the_push(tmp_path):
    root = _repo(tmp_path, with_origin=True)
    os.environ[budgets.ENV_MAX_PRS_PER_DAY] = "1"
    budgets.record_pr(workflow_execute._repo_key(root))

    with _publish_env(root) as gh_calls:
        with grant_env(repo="merge", actor="schedule:dep-bump"):
            out = workflow_execute.open_pull_request("t", title="chore: bump")

    assert out["ok"] is False
    assert out["prHeld"] is True and out["denied"] == budgets.BUDGET_PRS
    assert out["push"] == {"ok": True}, "the branch is pushed, only the PR waits"
    assert gh_calls == [], "gh pr create must not run"
    assert [b["tool"] for b in _events("budget_exceeded")] == [budgets.BUDGET_PRS]


def test_the_first_pr_of_the_day_counts_and_the_cap_applies_after_it(tmp_path):
    root = _repo(tmp_path, with_origin=True)
    os.environ[budgets.ENV_MAX_PRS_PER_DAY] = "1"
    key = workflow_execute._repo_key(root)

    with _publish_env(root) as gh_calls:
        with grant_env(repo="merge"):
            first = workflow_execute.open_pull_request("t", title="one")
            assert first["ok"] is True
            assert budgets.prs_today(key) == 1
            held = workflow_execute.open_pull_request("t", title="two")

    assert held["denied"] == budgets.BUDGET_PRS and held["prHeld"] is True
    assert len(gh_calls) == 1, "only the first PR reached gh"


def test_the_open_agent_pr_ledger_is_balanced_by_a_merge(tmp_path):
    root = _repo(tmp_path, with_origin=True)
    os.environ[budgets.ENV_MAX_OPEN_AGENT_PRS] = "2"
    key = workflow_execute._repo_key(root)
    budgets.record_pr(key)
    budgets.record_pr(key)

    with grant_env(repo="merge", actor="schedule:dep-bump"):
        assert budgets.open_agent_prs(key) == 2
        full = budgets.check_open_agent_prs(key)
        assert full.allowed is False and full.code == budgets.BUDGET_OPEN_PRS
        assert budgets.summary()["openAgentPrs"] == {key: 2}
        budgets.record_merge(key)
        assert budgets.check_open_agent_prs(key).allowed is True
    assert _events("budget_exceeded")[0]["tool"] == budgets.BUDGET_OPEN_PRS


def test_the_open_pr_ledger_is_per_repo():
    os.environ[budgets.ENV_MAX_OPEN_AGENT_PRS] = "1"
    budgets.record_pr("me/one")
    with grant_env(repo="merge"):
        assert budgets.check_open_agent_prs("me/two").allowed is True
        assert budgets.check_open_agent_prs("me/one").code == budgets.BUDGET_OPEN_PRS


def test_the_repo_key_follows_the_origin_and_falls_back_to_the_checkout(tmp_path):
    with_origin = _repo(tmp_path, with_origin=True)
    assert workflow_execute._repo_key(with_origin) == f"{tmp_path.name}/origin"

    plain = tmp_path / "plain"
    plain.mkdir()
    assert workflow_execute._repo_key(plain) == "local:plain"


# --- state on disk -------------------------------------------------------------------


def test_old_day_counters_are_pruned_and_today_survives():
    today = budgets._today()
    yesterday = (
        datetime.strptime(today, "%Y-%m-%d") - timedelta(days=30)
    ).date().isoformat()
    paths.budget_file().parent.mkdir(parents=True, exist_ok=True)

    def stale() -> str:
        return json.dumps(
            {
                "runs": {"schedule:nightly": {yesterday: 3, today: 1}},
                "prs": {"me/one": {yesterday: 9}},
                "openPrs": {"me/one": 2},
            }
        )

    paths.budget_file().write_text(stale(), encoding="utf-8")
    assert maintenance.prune_budget() == 2, "the stale runs day and the stale prs day"

    state = _read_state()
    assert state["runs"] == {"schedule:nightly": {today: 1}}
    assert state["prs"] == {}, "a repo with no PRs today leaves no entry"
    assert state["openPrs"] == {"me/one": 2}, "the open ledger is not day keyed"

    paths.budget_file().write_text(stale(), encoding="utf-8")
    assert maintenance.run_retention()["budget_days_dropped"] == 2


def test_summary_is_a_read_and_changes_nothing():
    os.environ[budgets.ENV_MAX_PRS_PER_DAY] = "3"
    budgets.record_pr("me/one")
    before = paths.budget_file().read_bytes()

    with grant_env(repo="pr", actor="schedule:daily-audit"):
        summary = budgets.summary()

    assert summary["applies"] is True and summary["actor"] == "schedule:daily-audit"
    assert summary["limits"]["maxPrsPerDay"] == 3
    assert "maxRunsPerDay" not in summary["limits"], "runs stay unlimited unless asked"
    assert summary["today"]["prsByRepo"] == {"me/one": 1}
    assert paths.budget_file().read_bytes() == before
    assert _events("budget_exceeded") == []


# --- transport -----------------------------------------------------------------------


def test_the_host_and_schedule_options_exist():
    options = (REPO / "nixos/modules/specialized/ncc-assistant/options.nix").read_text(
        encoding="utf-8"
    )
    for needle in (
        "budgetModule = types.submodule",
        "maxRunsPerDay",
        "maxPrsPerDay",
        "maxDiffLines",
        "maxOpenAgentPrs",
        "budget = mkOption",
    ):
        assert needle in options, needle


SCHEDULES_NIX = REPO / "nixos/modules/specialized/ncc-assistant/schedules.nix"

# The budget let-block, lifted verbatim so the test evaluates the module's own rule rather
# than a copy of it. Anchored on the bindings the unit's environment is built from.
BUDGET_BLOCK_RE = re.compile(r"  budgetKeys = \{.*?\n(?=  scheduleBudget = )", re.S)


def _nix_budget_env(host_budget: str, schedule_budget: str) -> dict:
    """Evaluate schedules.nix's real budget block: env vars a unit would actually get."""
    block = BUDGET_BLOCK_RE.search(SCHEDULES_NIX.read_text(encoding="utf-8"))
    assert block, "budget let-block missing from schedules.nix"
    nix = (
        "let\n"
        "  lib = (import <nixpkgs> { }).lib;\n"
        "in with lib;\n"
        "let\n"
        f"  cfg = {{ grants = {{ budget = {host_budget}; }}; }};\n"
        f"{block.group(0)}"
        f"  env = budgetEnvironment {{ permissions.budget = {schedule_budget}; }};\n"
        # budgetConflicts' own shape: any over a key of the schedule's budget attrset.
        "  loud = any (k: budgetOverreach "
        f"{schedule_budget} k) (attrNames budgetKeys);\n"
        "in { env = env; overreach = loud; }\n"
    )
    path = Path("/tmp/ncc-budget-block-eval.nix")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(nix, encoding="utf-8")
    out = subprocess.run(
        ["nix-instantiate", "--eval", "--strict", "--json", str(path)],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(out.stdout)


def test_the_schedule_unit_gets_the_env_and_narrowing_only_warnings():
    schedules = SCHEDULES_NIX.read_text(encoding="utf-8")
    for needle in (
        "// budgetEnvironment schedule",
        "NCC_ASSISTANT_BUDGET_MAX_RUNS_PER_DAY",
        "NCC_ASSISTANT_BUDGET_MAX_PRS_PER_DAY",
        "NCC_ASSISTANT_BUDGET_MAX_DIFF_LINES",
        "NCC_ASSISTANT_BUDGET_MAX_OPEN_AGENT_PRS",
        "budgetConflicts",
    ):
        assert needle in schedules, needle

    host = "{ maxPrsPerDay = 5; maxOpenAgentPrs = 4; }"
    runs = "NCC_ASSISTANT_BUDGET_MAX_RUNS_PER_DAY"
    prs = "NCC_ASSISTANT_BUDGET_MAX_PRS_PER_DAY"

    # A schedule that says nothing still inherits the host's counters.
    quiet = _nix_budget_env(host, "{ }")
    assert quiet["env"] == {
        "NCC_ASSISTANT_BUDGET_MAX_PRS_PER_DAY": "5",
        "NCC_ASSISTANT_BUDGET_MAX_OPEN_AGENT_PRS": "4",
    }
    assert quiet["overreach"] is False

    # A schedule may only narrow the host, so the smaller value wins and stays quiet.
    narrowed = _nix_budget_env(host, "{ maxPrsPerDay = 2; maxDiffLines = 500; }")
    assert narrowed["env"][prs] == "2"
    assert narrowed["env"]["NCC_ASSISTANT_BUDGET_MAX_DIFF_LINES"] == "500"
    assert narrowed["overreach"] is False, "narrowing is not a conflict"

    # Asking for more than the host is the host's value with a warning, never more rights.
    over = _nix_budget_env(host, "{ maxPrsPerDay = 99; }")
    assert over["env"][prs] == "5", "a schedule may not widen its host"
    assert over["overreach"] is True, "budgetConflicts has to see this schedule"

    # 0 = "off for this counter": honoured when the host left it open, never over a cap.
    assert _nix_budget_env("{ }", "{ maxRunsPerDay = 0; }")["env"][runs] == "0"
    assert _nix_budget_env(host, "{ maxPrsPerDay = 0; }")["env"][prs] == "5"

    # Nothing declared anywhere: no env at all, so budgets.py keeps its own defaults.
    assert _nix_budget_env("{ }", "{ }")["env"] == {}


def test_the_cli_shows_the_budget_and_prints_a_skip(capsys):
    src = (
        REPO / "nixos/modules/specialized/ncc-assistant/python/ncc_assistant/cli.py"
    ).read_text(encoding="utf-8")
    assert '"budget": budget' in src and 'kind == "skipped"' in src

    os.environ[budgets.ENV_MAX_PRS_PER_DAY] = "2"
    with grant_env(repo="pr", actor="schedule:daily-audit"):
        assert cli.main(["permissions", "show", "--json"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["budget"]["actor"] == "schedule:daily-audit"
    assert payload["budget"]["limits"]["maxPrsPerDay"] == 2


if __name__ == "__main__":
    pytest.main([__file__, "-q"])
