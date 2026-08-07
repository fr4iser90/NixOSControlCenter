"""Audit logging with secret redaction."""

from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass, asdict, field
from datetime import datetime, timezone
from typing import Any

from .paths import audit_file


SECRET_PATTERNS = [
    re.compile(r'(?i)(api[_-]?key|apikey|secret|password|token|auth|bearer)\s*[=:]\s*["\']?([^\s"\']+)', re.IGNORECASE),
    re.compile(r'(?i)authorization:\s*bearer\s+(\S+)', re.IGNORECASE),
    re.compile(r'sk-[a-zA-Z0-9]{20,}'),
    re.compile(r'ghp_[a-zA-Z0-9]{36}'),
    re.compile(r'gho_[a-zA-Z0-9]{36}'),
    re.compile(r'glpat-[a-zA-Z0-9\-_]{20,}'),
    re.compile(r'xox[baprs]-[a-zA-Z0-9\-]+'),
    re.compile(r'-----BEGIN\s+(?:RSA\s+)?PRIVATE\s+KEY-----[\s\S]*?-----END'),
]


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def redact_secrets(text: str) -> str:
    """Redact potential secrets from text."""
    result = text
    for pattern in SECRET_PATTERNS:
        if pattern.groups:
            result = pattern.sub(lambda m: m.group(0).replace(m.group(m.lastindex or 1), "[REDACTED]"), result)
        else:
            result = pattern.sub("[REDACTED]", result)
    return result


def redact_dict(data: dict[str, Any]) -> dict[str, Any]:
    """Recursively redact secrets from a dictionary."""
    result: dict[str, Any] = {}
    sensitive_keys = {
        "api_key", "apikey", "api-key", "secret", "password", "token",
        "auth", "authorization", "bearer", "credential", "credentials",
        "private_key", "privatekey", "private-key", "access_token",
        "refresh_token", "client_secret",
    }
    for key, value in data.items():
        lower_key = key.lower().replace("-", "_")
        if any(sk in lower_key for sk in sensitive_keys):
            result[key] = "[REDACTED]"
        elif isinstance(value, dict):
            result[key] = redact_dict(value)
        elif isinstance(value, list):
            result[key] = [
                redact_dict(v) if isinstance(v, dict)
                else redact_secrets(str(v)) if isinstance(v, str)
                else v
                for v in value
            ]
        elif isinstance(value, str):
            result[key] = redact_secrets(value)
        else:
            result[key] = value
    return result


@dataclass
class AuditEntry:
    """A single audit log entry."""
    timestamp: str = field(default_factory=_now_iso)
    event: str = ""
    actor: str = "agent"  # agent | user | system
    job_id: str | None = None
    session_id: str | None = None
    tool: str | None = None
    args: dict[str, Any] | None = None
    result: str | None = None  # ok | error | denied
    detail: str | None = None
    hostname: str | None = field(default_factory=lambda: os.environ.get("HOSTNAME") or os.uname().nodename)

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        return {k: v for k, v in d.items() if v is not None}


def append_audit(
    event: str,
    *,
    actor: str = "agent",
    job_id: str | None = None,
    session_id: str | None = None,
    tool: str | None = None,
    args: dict[str, Any] | None = None,
    result: str | None = None,
    detail: str | None = None,
) -> AuditEntry:
    """Append an entry to the audit log with redaction."""
    redacted_args = redact_dict(args) if args else None
    redacted_detail = redact_secrets(detail) if detail else None

    entry = AuditEntry(
        event=event,
        actor=actor,
        job_id=job_id,
        session_id=session_id,
        tool=tool,
        args=redacted_args,
        result=result,
        detail=redacted_detail,
    )

    path = audit_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry.to_dict(), ensure_ascii=False) + "\n")

    return entry


def read_audit(limit: int = 100, job_id: str | None = None) -> list[AuditEntry]:
    """Read recent audit entries, optionally filtered by job_id."""
    path = audit_file()
    if not path.is_file():
        return []

    entries: list[AuditEntry] = []
    try:
        with path.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    if job_id and data.get("job_id") != job_id:
                        continue
                    entries.append(AuditEntry(
                        timestamp=data.get("timestamp", ""),
                        event=data.get("event", ""),
                        actor=data.get("actor", "agent"),
                        job_id=data.get("job_id"),
                        session_id=data.get("session_id"),
                        tool=data.get("tool"),
                        args=data.get("args"),
                        result=data.get("result"),
                        detail=data.get("detail"),
                        hostname=data.get("hostname"),
                    ))
                except json.JSONDecodeError:
                    continue
    except OSError:
        pass

    entries.reverse()
    return entries[:limit]


def clear_audit() -> bool:
    """Clear the audit log."""
    path = audit_file()
    if path.is_file():
        path.unlink()
        return True
    return False
