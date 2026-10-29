"""State hygiene: secret-bearing files stay owner-only, unbounded state gets pruned."""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "nixos" / "modules" / "specialized" / "ncc-assistant"))

from core.policy.audit import append_audit
from core.store.jobs import JobStore
from core.catalogs.maintenance import prune_approvals, prune_audit, prune_jobs
from core.catalogs.marketplace import install_template
from core.policy.notifications import DecisionService, PendingDecision
from core.store.paths import audit_file, workspaces_file
from core.runtime.runtime import ToolRuntime
from core.store.secrets import set_secret
from core.store.workspaces import upsert_workspace


def _mode(path: Path) -> int:
    return path.stat().st_mode & 0o777


def _age(path: Path, *, days: float) -> None:
    stamp = (datetime.now(timezone.utc) - timedelta(days=days)).timestamp()
    os.utime(path, (stamp, stamp))


def _put_on_path(tmp_path: Path, name: str) -> None:
    """Make ``name`` resolve on PATH for the surrounding patched environment.

    ``install_template`` refuses a server whose command is missing, so an install test has to
    provide the launcher the packaged wrapper declares (uv ships uvx) rather than inherit
    whatever the machine running the gate happens to have installed.
    """
    bindir = tmp_path / "bin"
    bindir.mkdir(exist_ok=True)
    stub = bindir / name
    stub.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
    stub.chmod(0o755)
    os.environ["PATH"] = f"{bindir}{os.pathsep}{os.environ['PATH']}"


def test_workspaces_file_is_owner_only(tmp_path):
    with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(tmp_path)}):
        repo = tmp_path / "repo"
        repo.mkdir()
        upsert_workspace("ncc", str(repo), label="NCC")
        path = workspaces_file()
        assert path.is_file()
        assert _mode(path) == 0o600
        assert json.loads(path.read_text(encoding="utf-8"))["workspaces"][0]["id"] == "ncc"


def test_mcp_install_keeps_resolved_token_owner_only(tmp_path):
    with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(tmp_path)}):
        # The install refuses a server whose launcher is not on PATH, so the test states that
        # dependency instead of assuming whatever the machine running the gate happens to ship.
        # /bin/echo answers for uvx: install only asks whether the command exists.
        _put_on_path(tmp_path, "uvx")
        set_secret("github_token", "ghp_test-value-not-real")
        result = install_template("github")
        assert result["ok"] is True, result

        path = tmp_path / "ncc-assistant" / "mcp-servers.json"
        installed = json.loads(path.read_text(encoding="utf-8"))
        # Proves the file really holds the PAT, which is why the mode matters.
        assert installed["github"]["env"]["GITHUB_PERSONAL_ACCESS_TOKEN"] == "ghp_test-value-not-real"
        assert _mode(path) == 0o600


def test_an_unlaunchable_server_is_refused_before_its_token_is_written(tmp_path):
    """Install must not hand a PAT to a server that can never start.

    The spawn happens in a later run, so a missing launcher used to surface as success here and
    as "MCP call failed" inside an unattended agent run. An empty PATH is the real absence —
    nothing is mocked, so the refusal itself is what gets tested.
    """
    empty_path = tmp_path / "empty-bin"
    empty_path.mkdir()
    with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(tmp_path), "PATH": str(empty_path)}):
        set_secret("github_token", "ghp_test-value-not-real")
        result = install_template("github")

        assert result["ok"] is False, result
        assert "uvx" in result["error"], result
        servers = tmp_path / "ncc-assistant" / "mcp-servers.json"
        assert not servers.exists(), "a refused install wrote state anyway"
        # The PAT stays where it was stored: no other file under the config home holds it.
        carriers = [
            p
            for p in tmp_path.rglob("*")
            if p.is_file()
            and p.name != "secrets.json"
            and "ghp_test-value-not-real" in p.read_text(errors="ignore")
        ]
        assert not carriers, f"the token escaped the store: {[str(p) for p in carriers]}"


def test_approval_write_is_owner_only(tmp_path):
    with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(tmp_path)}):
        svc = DecisionService()
        decision = PendingDecision(kind="tool_approval", title="Push", tool="git_push")
        svc._write(decision)
        path = tmp_path / "ncc-assistant" / "approvals" / f"{decision.id}.json"
        assert path.is_file()
        assert _mode(path) == 0o600


def test_audit_file_is_owner_only_after_append(tmp_path):
    with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(tmp_path)}):
        append_audit("tool_call", actor="agent", tool="shell_run", args={"command": "git status"})
        assert _mode(audit_file()) == 0o600


def test_prune_approvals_keeps_pending_and_recent(tmp_path):
    with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(tmp_path)}):
        import core.policy.notifications as notifications

        notifications._default_service = None
        try:
            svc = DecisionService()
            old_decided = PendingDecision(kind="tool_approval", title="old decided")
            old_decided.result = "allow"
            old_decided.decided_at = datetime.now(timezone.utc).isoformat()
            fresh_decided = PendingDecision(kind="tool_approval", title="fresh decided")
            fresh_decided.result = "block"
            old_pending = PendingDecision(kind="tool_approval", title="old pending")
            for decision in (old_decided, fresh_decided, old_pending):
                svc._write(decision)

            base = tmp_path / "ncc-assistant" / "approvals"
            _age(base / f"{old_decided.id}.json", days=30)
            _age(base / f"{old_pending.id}.json", days=30)

            assert prune_approvals(max_age_days=7) == 1
            assert not (base / f"{old_decided.id}.json").exists()
            assert (base / f"{fresh_decided.id}.json").is_file()
            assert (base / f"{old_pending.id}.json").is_file()
        finally:
            notifications._default_service = None


def test_prune_audit_keeps_newest_lines(tmp_path):
    with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(tmp_path)}):
        for i in range(6):
            append_audit("tool_call", actor="agent", detail=f"event-{i}")
        path = audit_file()
        assert len(path.read_text(encoding="utf-8").splitlines()) == 6

        assert prune_audit(keep=2) == 4
        remaining = path.read_text(encoding="utf-8").splitlines()
        assert len(remaining) == 2
        assert json.loads(remaining[-1])["detail"] == "event-5"
        assert _mode(path) == 0o600


def test_prune_jobs_keeps_running_and_newest(tmp_path):
    with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(tmp_path)}):
        store = JobStore()
        finished = []
        for i in range(3):
            meta = store.create(f"goal {i}")
            store.finalize(meta.id, success=True, summary="done")
            finished.append(meta.id)
        running = store.create("still running").id

        base = tmp_path / "ncc-assistant" / "jobs"
        # finished[-1] gets the newest mtime, so it is the one keep=1 must retain.
        for i, job_id in enumerate(finished):
            _age(base / job_id, days=len(finished) - i)
        _age(base / running, days=90)

        assert prune_jobs(keep=1, max_age_days=30) == 2
        assert (base / finished[-1]).is_dir()
        assert (base / running).is_dir()
        assert not (base / finished[0]).exists()
        assert not (base / finished[1]).exists()


def _shell_runtime() -> ToolRuntime:
    from core.store.config import Settings

    return ToolRuntime(Settings.from_env())


def test_shell_denied_when_allowlist_empty(tmp_path):
    with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(tmp_path), "NCC_ASSISTANT_ALLOW_SHELL": "1"}):
        os.environ.pop("NCC_ASSISTANT_SHELL_ALLOWLIST", None)
        rt = _shell_runtime()
        assert rt.settings.allow_shell is True
        assert rt._shell_allowlisted("git status") is False
        denied = rt._call_shell_tool("git_status", {}, "git status")
        assert denied["ok"] is False
        assert "shellAllowlist is empty" in denied["error"]


def test_shell_allowlist_matches_prefixes_only(tmp_path):
    with mock.patch.dict(
        os.environ,
        {"XDG_CONFIG_HOME": str(tmp_path), "NCC_ASSISTANT_ALLOW_SHELL": "1", "NCC_ASSISTANT_SHELL_ALLOWLIST": "git:df"},
    ):
        rt = _shell_runtime()
        assert rt._shell_allowlisted("git status") is True
        assert rt._shell_allowlisted("df -h") is True
        assert rt._shell_allowlisted("rm -rf /tmp/x") is False
        # A prefix must not match a different binary that merely starts with those letters.
        assert rt._shell_allowlisted("gitk --all") is False

        denied = rt._call_shell_tool("danger", {}, "rm -rf /tmp/ncc-hygiene-test")
        assert denied["ok"] is False
        assert "not in allowlist" in denied["error"]
