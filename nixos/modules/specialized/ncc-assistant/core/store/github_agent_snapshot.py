"""GitHub Agent board snapshot (SSOT for Companion PANEL_GITHUB).

Callers: ``core.workflows.github_agent.run_github_agent``, CLI
``ncc ai github-agent show``, Companion ``_fill_panel(PANEL_GITHUB)``,
``tests/ncc-assistant/test_github_agent_v1.py``.

No duplicate of ``workflows/daily.json`` — this is the fleet board view;
Daily holds per-gap tasks. Schema version 1 under ``github-agent/snapshot.json`` (0600).

User intent: one board row per registered project (state, gaps, next task, drift).
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from typing import Any

from core.store.paths import github_agent_snapshot_file

SCHEMA_VERSION = 1


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def empty_snapshot() -> dict[str, Any]:
    return {
        "version": SCHEMA_VERSION,
        "updatedAt": _now(),
        "operatorFacts": {},
        "projects": [],
        "drift": {},
        "jobId": "",
    }


def load_github_agent_snapshot() -> dict[str, Any] | None:
    path = github_agent_snapshot_file()
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(data, dict):
        return None
    return data


def save_github_agent_snapshot(data: dict[str, Any]) -> dict[str, Any]:
    path = github_agent_snapshot_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = dict(data)
    payload["version"] = SCHEMA_VERSION
    payload["updatedAt"] = str(payload.get("updatedAt") or _now())
    if "projects" not in payload or not isinstance(payload["projects"], list):
        payload["projects"] = []
    if "operatorFacts" not in payload or not isinstance(payload["operatorFacts"], dict):
        payload["operatorFacts"] = {}
    if "drift" not in payload or not isinstance(payload["drift"], dict):
        payload["drift"] = {}
    payload["jobId"] = str(payload.get("jobId") or "")
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass
    return payload
