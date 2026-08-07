"""Domain catalog — loaded only from NCC_GUI_CATALOG (Nix/registry). No hardcoded modules."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field


@dataclass
class DomainAction:
    label: str
    args: list[str]


@dataclass
class DomainInfo:
    id: str
    label: str
    description: str
    enabled: bool
    group: str = "features"  # "core" | "features"
    actions: list[DomainAction] = field(default_factory=list)


def _group_rank(group: str) -> int:
    return 0 if group == "core" else 1


def load_domains() -> list[DomainInfo]:
    """
    NCC_GUI_CATALOG must be a JSON list produced by cli-registry, e.g.:

      [
        {
          "id": "packages",
          "label": "Packages",
          "description": "...",
          "enabled": true,
          "group": "core",
          "actions": [{"label": "List", "args": ["list"]}]
        }
      ]

    Empty / missing → no sidebar entries (nothing hardcoded).
    """
    raw = os.environ.get("NCC_GUI_CATALOG", "").strip()
    if not raw:
        return []

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return []

    if not isinstance(data, list):
        return []

    out: list[DomainInfo] = []
    for item in data:
        if not isinstance(item, dict) or not item.get("id"):
            continue
        actions_raw = item.get("actions") or []
        actions: list[DomainAction] = []
        if isinstance(actions_raw, list):
            for a in actions_raw:
                if isinstance(a, dict) and a.get("label") and isinstance(a.get("args"), list):
                    actions.append(
                        DomainAction(
                            label=str(a["label"]),
                            args=[str(x) for x in a["args"]],
                        )
                    )
        group = str(item.get("group") or "features")
        if group not in ("core", "features"):
            group = "features"
        out.append(
            DomainInfo(
                id=str(item["id"]),
                label=str(item.get("label") or item["id"]),
                description=str(item.get("description") or ""),
                enabled=bool(item.get("enabled", True)),
                group=group,
                actions=actions,
            )
        )
    # Core first, then features; stable by label within group
    out.sort(key=lambda d: (_group_rank(d.group), d.label.lower()))
    return out
