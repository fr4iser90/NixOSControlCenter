"""GitHub Agent multi-day campaign (resume SSOT).

Callers: ``core.workflows.github_agent_act`` (arm/tick/pause/resume),
``cli.cli._cmd_github_agent``, Companion PANEL_GITHUB campaign row,
``core.scheduling.idle.maybe_sweep``, tests ``test_github_agent_autonomy_v1``.

No existing file holds fleet wave state (JobStore does not resume mid-run;
``workflow_progress`` is per-workspace only). Writes/reads
``github-agent/campaign.json`` schema v1 (queue/done/skipped/status).

User: "autonmm mehre tage läuft , falls disconnected ausgeht er wieder
angeht vllt sogar da weitermacht etc"
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from typing import Any

from core.store.paths import github_agent_campaign_file

SCHEMA_VERSION = 1
STATUSES = ("idle", "running", "paused", "done")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def empty_campaign() -> dict[str, Any]:
    return {
        "version": SCHEMA_VERSION,
        "status": "idle",
        "mode": "act-safe",
        "startedAt": "",
        "updatedAt": _now(),
        "lastTickAt": "",
        "sourceJobId": "",
        "cursor": None,
        "queue": [],
        "done": [],
        "skipped": [],
        "errors": [],
        "stats": {"applied": 0, "skipped": 0, "errors": 0, "ticks": 0},
    }


def load_github_agent_campaign() -> dict[str, Any]:
    path = github_agent_campaign_file()
    if not path.is_file():
        return empty_campaign()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return empty_campaign()
    if not isinstance(data, dict):
        return empty_campaign()
    out = empty_campaign()
    out.update({k: data[k] for k in out if k in data})
    if out.get("status") not in STATUSES:
        out["status"] = "idle"
    for key in ("queue", "done", "skipped", "errors"):
        if not isinstance(out.get(key), list):
            out[key] = []
    if not isinstance(out.get("stats"), dict):
        out["stats"] = empty_campaign()["stats"]
    return out


def save_github_agent_campaign(data: dict[str, Any]) -> dict[str, Any]:
    path = github_agent_campaign_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = empty_campaign()
    payload.update(dict(data))
    payload["version"] = SCHEMA_VERSION
    payload["updatedAt"] = _now()
    if payload.get("status") not in STATUSES:
        payload["status"] = "idle"
    for key in ("queue", "done", "skipped", "errors"):
        if not isinstance(payload.get(key), list):
            payload[key] = []
    if not isinstance(payload.get("stats"), dict):
        payload["stats"] = empty_campaign()["stats"]
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass
    return payload
