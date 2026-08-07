"""Job store for agent runs under jobs/<id>/ with meta, events, and results."""

from __future__ import annotations

import fcntl
import json
import os
import uuid
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

from .paths import jobs_dir, agent_lock_file


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _generate_job_id() -> str:
    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    return f"{ts}-{uuid.uuid4().hex[:8]}"


@dataclass
class JobMeta:
    """Metadata for a job."""
    id: str
    goal: str
    status: str = "pending"  # pending | running | completed | failed | cancelled
    profile: str | None = None
    dry_run: bool = False
    playbook: str | None = None
    created_at: str = field(default_factory=_now_iso)
    started_at: str | None = None
    finished_at: str | None = None
    step_count: int = 0
    error: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "JobMeta":
        return cls(
            id=data["id"],
            goal=data.get("goal", ""),
            status=data.get("status", "pending"),
            profile=data.get("profile"),
            dry_run=data.get("dry_run", False),
            playbook=data.get("playbook"),
            created_at=data.get("created_at", _now_iso()),
            started_at=data.get("started_at"),
            finished_at=data.get("finished_at"),
            step_count=data.get("step_count", 0),
            error=data.get("error"),
        )


@dataclass
class JobEvent:
    """An event in a job's event log."""
    kind: str  # step | tool | tool_result | assistant | error | status
    timestamp: str = field(default_factory=_now_iso)
    data: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class JobResult:
    """Final result of a job."""
    success: bool
    summary: str = ""
    output: Any = None
    error: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class JobStore:
    """
    Manages job storage under ~/.config/ncc-assistant/jobs/<id>/.
    Each job has:
    - meta.json: Job metadata
    - events.jsonl: Event stream
    - result.json: Final result (when complete)
    """

    def __init__(self) -> None:
        self._base = jobs_dir()

    def _job_dir(self, job_id: str) -> Path:
        return self._base / job_id

    def create(
        self,
        goal: str,
        *,
        profile: str | None = None,
        dry_run: bool = False,
        playbook: str | None = None,
    ) -> JobMeta:
        """Create a new job and return its metadata."""
        job_id = _generate_job_id()
        job_dir = self._job_dir(job_id)
        job_dir.mkdir(parents=True, exist_ok=True)

        meta = JobMeta(
            id=job_id,
            goal=goal,
            profile=profile,
            dry_run=dry_run,
            playbook=playbook,
        )
        self._write_meta(meta)
        return meta

    def _write_meta(self, meta: JobMeta) -> None:
        path = self._job_dir(meta.id) / "meta.json"
        path.write_text(json.dumps(meta.to_dict(), indent=2) + "\n", encoding="utf-8")

    def get(self, job_id: str) -> JobMeta | None:
        """Get job metadata by ID."""
        path = self._job_dir(job_id) / "meta.json"
        if not path.is_file():
            return None
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            return JobMeta.from_dict(data)
        except (OSError, json.JSONDecodeError):
            return None

    def list_jobs(self, limit: int = 50) -> list[JobMeta]:
        """List recent jobs, newest first."""
        jobs: list[JobMeta] = []
        if not self._base.is_dir():
            return jobs
        for job_dir in self._base.iterdir():
            if not job_dir.is_dir():
                continue
            meta = self.get(job_dir.name)
            if meta:
                jobs.append(meta)
        jobs.sort(key=lambda j: j.created_at, reverse=True)
        return jobs[:limit]

    def start(self, job_id: str) -> JobMeta | None:
        """Mark job as running."""
        meta = self.get(job_id)
        if not meta:
            return None
        meta.status = "running"
        meta.started_at = _now_iso()
        self._write_meta(meta)
        return meta

    def append_event(self, job_id: str, event: JobEvent) -> None:
        """Append an event to the job's event log."""
        path = self._job_dir(job_id) / "events.jsonl"
        with path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(event.to_dict(), ensure_ascii=False) + "\n")

    def get_events(self, job_id: str) -> Iterator[JobEvent]:
        """Iterate over job events."""
        path = self._job_dir(job_id) / "events.jsonl"
        if not path.is_file():
            return
        with path.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    yield JobEvent(
                        kind=data.get("kind", "unknown"),
                        timestamp=data.get("timestamp", ""),
                        data=data.get("data", {}),
                    )
                except json.JSONDecodeError:
                    continue

    def finalize(
        self,
        job_id: str,
        *,
        success: bool,
        summary: str = "",
        output: Any = None,
        error: str | None = None,
    ) -> JobMeta | None:
        """Mark job as complete/failed and write result."""
        meta = self.get(job_id)
        if not meta:
            return None

        meta.status = "completed" if success else "failed"
        meta.finished_at = _now_iso()
        if error:
            meta.error = error
        self._write_meta(meta)

        result = JobResult(
            success=success,
            summary=summary,
            output=output,
            error=error,
        )
        result_path = self._job_dir(job_id) / "result.json"
        result_path.write_text(json.dumps(result.to_dict(), indent=2) + "\n", encoding="utf-8")
        return meta

    def get_result(self, job_id: str) -> JobResult | None:
        """Get the final result of a completed job."""
        path = self._job_dir(job_id) / "result.json"
        if not path.is_file():
            return None
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            return JobResult(
                success=data.get("success", False),
                summary=data.get("summary", ""),
                output=data.get("output"),
                error=data.get("error"),
            )
        except (OSError, json.JSONDecodeError):
            return None

    def increment_steps(self, job_id: str) -> int:
        """Increment and return step count."""
        meta = self.get(job_id)
        if not meta:
            return 0
        meta.step_count += 1
        self._write_meta(meta)
        return meta.step_count

    def cancel(self, job_id: str) -> JobMeta | None:
        """Mark job as cancelled."""
        meta = self.get(job_id)
        if not meta:
            return None
        if meta.status in ("completed", "failed", "cancelled"):
            return meta
        meta.status = "cancelled"
        meta.finished_at = _now_iso()
        self._write_meta(meta)
        return meta


class AgentLock:
    """
    File-based lock to ensure only one agent runs at a time.
    Uses flock for advisory locking.
    """

    def __init__(self) -> None:
        self._lock_path = agent_lock_file()
        self._lock_file: Any = None
        self._locked = False

    def acquire(self, blocking: bool = True) -> bool:
        """
        Acquire the agent lock.
        Returns True if lock acquired, False if non-blocking and lock busy.
        """
        self._lock_path.parent.mkdir(parents=True, exist_ok=True)
        self._lock_file = self._lock_path.open("w", encoding="utf-8")

        try:
            flags = fcntl.LOCK_EX
            if not blocking:
                flags |= fcntl.LOCK_NB
            fcntl.flock(self._lock_file.fileno(), flags)
            self._locked = True
            self._lock_file.write(f"{os.getpid()}\n")
            self._lock_file.flush()
            return True
        except BlockingIOError:
            self._lock_file.close()
            self._lock_file = None
            return False

    def release(self) -> None:
        """Release the agent lock."""
        if self._lock_file is not None:
            try:
                fcntl.flock(self._lock_file.fileno(), fcntl.LOCK_UN)
            except Exception:
                pass
            self._lock_file.close()
            self._lock_file = None
            self._locked = False

    def __enter__(self) -> "AgentLock":
        self.acquire(blocking=True)
        return self

    def __exit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> None:
        self.release()

    @property
    def is_locked(self) -> bool:
        return self._locked


_default_store: JobStore | None = None


def get_job_store() -> JobStore:
    """Get or create the default job store."""
    global _default_store
    if _default_store is None:
        _default_store = JobStore()
    return _default_store
