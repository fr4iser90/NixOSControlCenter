"""Notifications and decision service for agent approval workflows."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import threading
import time
import uuid
from dataclasses import dataclass, asdict, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Literal

from .paths import approvals_dir


DecisionResult = Literal["allow", "block", "wait", "timeout"]
TimeoutAction = Literal["block", "queue", "pause"]


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _notifications_enabled() -> bool:
    """Return True unless NOTIFY_ENABLE / NCC_ASSISTANT_NOTIFY_ENABLE disables."""
    for key in ("NOTIFY_ENABLE", "NCC_ASSISTANT_NOTIFY_ENABLE"):
        raw = os.environ.get(key)
        if raw is not None and raw != "":
            return raw.lower() in ("1", "true", "yes")
    return True


def notify_send(
    title: str,
    body: str = "",
    *,
    urgency: str = "normal",
    timeout_ms: int = 5000,
    icon: str | None = None,
) -> bool:
    """Send a desktop notification via notify-send (no action buttons)."""
    if not _notifications_enabled():
        return False
    if not shutil.which("notify-send"):
        return False

    cmd = ["notify-send", "--app-name", "NCC AI"]
    cmd.extend(["--urgency", urgency])
    cmd.extend(["--expire-time", str(timeout_ms)])
    if icon:
        cmd.extend(["--icon", icon])
    cmd.append(title)
    if body:
        cmd.append(body)

    try:
        result = subprocess.run(cmd, capture_output=True, timeout=10)
        return result.returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        return False


def notify_send_actions(
    title: str,
    body: str = "",
    *,
    actions: list[tuple[str, str]] | None = None,
    urgency: str = "critical",
    timeout_ms: int = 300_000,
    icon: str | None = None,
) -> str | None:
    """
    Show a notification with action buttons (Allow / Block / …).

    Uses `notify-send --action` (implies --wait). Returns the chosen action
    NAME, or None if dismissed/expired without a click.
    """
    if not _notifications_enabled():
        return None
    if not shutil.which("notify-send"):
        return None

    acts = actions or [
        ("allow", "Allow"),
        ("block", "Block"),
        ("wait", "Wait"),
    ]

    cmd = ["notify-send", "--app-name", "NCC AI"]
    cmd.extend(["--urgency", urgency])
    # expire-time is max wait when --action is used
    cmd.extend(["--expire-time", str(max(1000, timeout_ms))])
    if icon:
        cmd.extend(["--icon", icon])
    else:
        cmd.extend(["--icon", "dialog-warning"])
    for name, label in acts:
        cmd.append(f"--action={name}={label}")
    cmd.append(title)
    if body:
        cmd.append(body)

    # Block until user clicks an action or the notification expires/closes.
    # Add a small buffer beyond expire-time so the process can exit cleanly.
    wait_timeout = max(30.0, (timeout_ms / 1000.0) + 15.0)
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=wait_timeout,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return None
    except OSError:
        return None

    chosen = (result.stdout or "").strip().splitlines()
    if not chosen:
        return None
    action = chosen[-1].strip()
    return action or None


# Alias used by callers expecting a short name
notify = notify_send


def notify_agent_event(
    event: str,
    detail: str = "",
    *,
    urgency: str = "normal",
) -> bool:
    """Send a notification about an agent event."""
    if not _notifications_enabled():
        return False
    return notify_send(f"NCC Assistant: {event}", detail, urgency=urgency)


@dataclass
class PendingDecision:
    """A pending decision request."""
    id: str = field(default_factory=lambda: uuid.uuid4().hex[:12])
    kind: str = "tool_approval"  # tool_approval | write_confirm | rebuild_confirm
    title: str = ""
    summary: str = ""
    detail: str = ""
    tool: str | None = None
    args: dict[str, Any] | None = None
    job_id: str | None = None
    created_at: str = field(default_factory=_now_iso)
    expires_at: str | None = None
    result: DecisionResult | None = None
    decided_at: str | None = None

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        return {k: v for k, v in d.items() if v is not None}

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "PendingDecision":
        return cls(
            id=data.get("id", ""),
            kind=data.get("kind", "tool_approval"),
            title=data.get("title", ""),
            summary=data.get("summary", ""),
            detail=data.get("detail", ""),
            tool=data.get("tool"),
            args=data.get("args"),
            job_id=data.get("job_id"),
            created_at=data.get("created_at", _now_iso()),
            expires_at=data.get("expires_at"),
            result=data.get("result"),
            decided_at=data.get("decided_at"),
        )


class DecisionService:
    """
    File-based decision service for agent approval workflows.
    Decisions are stored under ~/.config/ncc-assistant/approvals/

    Desktop notifications include Allow / Block / Wait buttons via
    `notify-send --action`. CLI `approve` and tray still work in parallel.
    """

    def __init__(self) -> None:
        self._base = approvals_dir()

    def _decision_path(self, decision_id: str) -> Path:
        return self._base / f"{decision_id}.json"

    def create(
        self,
        kind: str,
        title: str,
        summary: str,
        *,
        detail: str = "",
        tool: str | None = None,
        args: dict[str, Any] | None = None,
        job_id: str | None = None,
        timeout_sec: int | None = None,
    ) -> PendingDecision:
        """Create a pending decision and show an actionable desktop notification."""
        expires_at = None
        if timeout_sec:
            from datetime import timedelta
            expires_at = (datetime.now(timezone.utc) + timedelta(seconds=timeout_sec)).isoformat()

        decision = PendingDecision(
            kind=kind,
            title=title,
            summary=summary,
            detail=detail,
            tool=tool,
            args=args,
            job_id=job_id,
            expires_at=expires_at,
        )

        self._base.mkdir(parents=True, exist_ok=True)
        self._write(decision)

        timeout = timeout_sec or int(
            os.environ.get("NOTIFY_TIMEOUT_SEC")
            or os.environ.get("NCC_ASSISTANT_NOTIFY_TIMEOUT_SEC")
            or "300"
        )
        urgency = "critical" if "rebuild" in kind else "normal"
        self._spawn_action_notification(decision, timeout_sec=timeout, urgency=urgency)

        return decision

    def _spawn_action_notification(
        self,
        decision: PendingDecision,
        *,
        timeout_sec: int,
        urgency: str,
    ) -> None:
        """Background thread: notify-send Allow/Block/Wait → write decision."""

        def _run() -> None:
            body_parts = [decision.summary]
            if decision.tool:
                body_parts.append(f"Tool: {decision.tool}")
            if decision.detail:
                body_parts.append(decision.detail[:400])
            body_parts.append(f"ID: {decision.id}")
            body = "\n".join(p for p in body_parts if p)

            action = notify_send_actions(
                f"NCC AI: {decision.title or 'Approval needed'}",
                body,
                actions=[
                    ("allow", "Allow"),
                    ("block", "Block"),
                    ("wait", "Wait"),
                ],
                urgency=urgency,
                timeout_ms=timeout_sec * 1000,
            )

            # Already decided via CLI/tray?
            current = self.get(decision.id)
            if current is None or current.result is not None:
                return

            if action == "allow":
                self.allow(decision.id)
            elif action == "block":
                self.block(decision.id)
            elif action == "wait":
                self.decide(decision.id, "wait")
            # else: dismissed — leave pending for wait_for_decision timeout

        thread = threading.Thread(
            target=_run,
            name=f"ncc-notify-{decision.id}",
            daemon=True,
        )
        thread.start()

    def _write(self, decision: PendingDecision) -> None:
        path = self._decision_path(decision.id)
        path.write_text(json.dumps(decision.to_dict(), indent=2) + "\n", encoding="utf-8")

    def get(self, decision_id: str) -> PendingDecision | None:
        """Get a decision by ID."""
        path = self._decision_path(decision_id)
        if not path.is_file():
            return None
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            return PendingDecision.from_dict(data)
        except (OSError, json.JSONDecodeError):
            return None

    def list_pending(self) -> list[PendingDecision]:
        """List all pending (undecided) decisions."""
        pending: list[PendingDecision] = []
        if not self._base.is_dir():
            return pending
        for path in self._base.glob("*.json"):
            decision = self.get(path.stem)
            if decision and decision.result is None:
                if decision.expires_at:
                    try:
                        exp = datetime.fromisoformat(decision.expires_at.replace("Z", "+00:00"))
                        if exp < datetime.now(timezone.utc):
                            continue
                    except ValueError:
                        pass
                pending.append(decision)
        pending.sort(key=lambda d: d.created_at)
        return pending

    def decide(self, decision_id: str, result: DecisionResult) -> PendingDecision | None:
        """Record a decision result."""
        decision = self.get(decision_id)
        if not decision:
            return None
        decision.result = result
        decision.decided_at = _now_iso()
        self._write(decision)
        return decision

    def allow(self, decision_id: str) -> PendingDecision | None:
        """Allow a pending decision."""
        return self.decide(decision_id, "allow")

    def block(self, decision_id: str) -> PendingDecision | None:
        """Block a pending decision."""
        return self.decide(decision_id, "block")

    def wait_for_decision(
        self,
        decision_id: str,
        timeout_sec: int = 300,
        poll_interval: float = 0.5,
    ) -> DecisionResult:
        """
        Poll for a decision result (notification button, CLI, or tray).
        Returns the result or handles timeout according to env setting.
        """
        deadline = time.time() + timeout_sec

        while time.time() < deadline:
            decision = self.get(decision_id)
            if decision and decision.result:
                return decision.result

            if decision and decision.expires_at:
                try:
                    exp = datetime.fromisoformat(decision.expires_at.replace("Z", "+00:00"))
                    if exp < datetime.now(timezone.utc):
                        break
                except ValueError:
                    pass

            time.sleep(poll_interval)

        on_timeout = (
            os.environ.get("NCC_ASSISTANT_NOTIFY_ON_TIMEOUT")
            or os.environ.get("NOTIFY_ON_TIMEOUT")
            or "block"
        ).lower()
        if on_timeout == "queue":
            self.decide(decision_id, "wait")
            return "wait"
        if on_timeout == "pause":
            from .presence import pause
            pause(reason=f"Decision timeout: {decision_id}")
            self.decide(decision_id, "block")
            return "block"
        self.decide(decision_id, "block")
        return "block"

    def cleanup_old(self, max_age_days: int = 7) -> int:
        """Remove old decided decisions."""
        if not self._base.is_dir():
            return 0
        count = 0
        cutoff = datetime.now(timezone.utc).timestamp() - (max_age_days * 86400)
        for path in self._base.glob("*.json"):
            try:
                if path.stat().st_mtime < cutoff:
                    decision = self.get(path.stem)
                    if decision and decision.result:
                        path.unlink()
                        count += 1
            except OSError:
                pass
        return count


_default_service: DecisionService | None = None


def get_decision_service() -> DecisionService:
    """Get or create the default decision service."""
    global _default_service
    if _default_service is None:
        _default_service = DecisionService()
    return _default_service
