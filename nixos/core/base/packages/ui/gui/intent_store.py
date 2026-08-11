"""Store intent helpers — match curated catalog intents locally (same JSON as CLI).

Store shows individual apps (kind=attr) and rare guided tips.
Sets / recipes belong in the Recipes & sets tab, not here.
"""

from __future__ import annotations

import re
from typing import Any

# What the Store tab lists / searches
STORE_KINDS = frozenset({"attr", "guided"})


def _norm(s: str) -> str:
    return re.sub(r"\s+", " ", (s or "").strip().lower())


def is_store_intent(intent: dict[str, Any]) -> bool:
    return str(intent.get("kind") or "") in STORE_KINDS


def store_intents(catalog: dict[str, Any]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for it in catalog.get("intents") or []:
        if isinstance(it, dict) and is_store_intent(it):
            out.append(it)
    return out


def score_intent(query: str, intent: dict[str, Any]) -> int:
    q = _norm(query)
    if not q:
        return 0
    names = [_norm(x) for x in (intent.get("aliases") or [])]
    names.append(_norm(str(intent.get("id") or "")))
    names.append(_norm(str(intent.get("title") or "")))
    names = [n for n in names if n]
    if any(n == q for n in names):
        return 100
    if any(n.startswith(q) for n in names):
        return 80
    if len(q) >= 3 and any(len(n) >= 3 and q.startswith(n) for n in names):
        return 70
    if any(q in n for n in names):
        return 60
    desc = _norm(str(intent.get("description") or ""))
    if q in desc:
        return 40
    if _norm(str(intent.get("category") or "")) == q:
        return 30
    return 0


def search_intents(
    catalog: dict[str, Any],
    query: str,
    *,
    store_only: bool = True,
) -> list[dict[str, Any]]:
    scored: list[tuple[int, dict[str, Any]]] = []
    for it in catalog.get("intents") or []:
        if not isinstance(it, dict):
            continue
        if store_only and not is_store_intent(it):
            continue
        s = score_intent(query, it)
        if s > 0:
            row = dict(it)
            row["_score"] = s
            scored.append((s, row))
    scored.sort(key=lambda x: (-x[0], str(x[1].get("title") or "").lower()))
    return [r for _, r in scored]


def intents_in_category(
    catalog: dict[str, Any],
    category_id: str,
    *,
    store_only: bool = True,
) -> list[dict[str, Any]]:
    cid = _norm(category_id)
    out: list[dict[str, Any]] = []
    for it in catalog.get("intents") or []:
        if not isinstance(it, dict):
            continue
        if store_only and not is_store_intent(it):
            continue
        if _norm(str(it.get("category") or "")) == cid:
            out.append(it)
    return sorted(out, key=lambda x: str(x.get("title") or "").lower())


def install_status(
    intent: dict[str, Any],
    *,
    mine: set[str] | list[str] | None = None,
    active_sets: set[str] | list[str] | None = None,
) -> dict[str, Any]:
    """How this Store app relates to the current config.

    Returns keys: state (missing|user|set|both), label, via_user, via_set.
    """
    mine_set = {str(x) for x in (mine or [])}
    active = {str(x) for x in (active_sets or [])}
    attr = str(intent.get("attr") or "")
    part = intent.get("partOfSet")
    part_s = str(part) if part else ""
    via_user = bool(attr) and attr in mine_set
    via_set = bool(part_s) and part_s in active
    if via_user and via_set:
        state = "both"
        label = f"installed (userPackages + set:{part_s})"
    elif via_user:
        state = "user"
        label = "installed (userPackages)"
    elif via_set:
        state = "set"
        label = f"installed via set:{part_s}"
    else:
        state = "missing"
        label = "not installed"
    return {
        "state": state,
        "label": label,
        "via_user": via_user,
        "via_set": via_set,
    }


def format_intent_details(
    intent: dict[str, Any],
    *,
    status: dict[str, Any] | None = None,
) -> str:
    kind = intent.get("kind") or "?"
    scope = intent.get("scope") or "?"
    lines = [
        str(intent.get("title") or intent.get("id") or ""),
        "",
        f"Kind: {kind} (individual app)" if kind == "attr" else f"Kind: {kind}",
        f"Scope: {scope}",
        str(intent.get("description") or ""),
    ]
    if status:
        lines.append(f"Status: {status.get('label') or 'unknown'}")
    attr = intent.get("attr")
    if attr:
        lines.append(f"Package attr: {attr}")
    part = intent.get("partOfSet")
    if part:
        lines.append(
            f"Also in set: {part}  →  enable under Sets & recipes for the full bundle"
        )
    if intent.get("tryable"):
        lines.append("Try: available (temporary nix-shell, no config write)")
    else:
        lines.append("Try: not available")
    if intent.get("requiresAdmin"):
        lines.append("Needs: administrator (machine-wide change)")
    else:
        lines.append("Needs: your user account only (userPackages)")
    if intent.get("requiresUnfree"):
        lines.append("Note: unfree package — allowUnfree must be enabled")
    lines.extend(
        [
            "",
            "Versions / updates (NixOS):",
            "  Apps follow your flake nixpkgs pin — there is no apt-style",
            "  per-package upgrade. To refresh all packages: Update nixpkgs…",
            "  (channels / flake inputs) then Rebuild.",
        ]
    )
    notes = intent.get("notes")
    if notes:
        lines.extend(["", str(notes)])
    related = intent.get("related") or []
    if related:
        lines.extend(["", "Related: " + ", ".join(str(x) for x in related)])
    return "\n".join(lines)


def stage_argv_for_intent(intent: dict[str, Any]) -> tuple[str, list[str], bool] | None:
    """Return (summary, packages-cli argv without binary, elevated) or None.

    Store apps stage user package adds. Guided intents return None (UI explains).
    """
    kind = intent.get("kind") or ""
    attr = intent.get("attr")

    if kind == "attr" and attr:
        return (
            f"add {attr}",
            ["packages", "add", str(attr), "--no-build"],
            False,
        )
    # guided / anything else: no automatic module staging from Store
    return None


def undo_argv_for_intent(intent: dict[str, Any]) -> tuple[list[str], bool] | None:
    kind = intent.get("kind") or ""
    attr = intent.get("attr")
    if kind == "attr" and attr:
        return (["packages", "remove", str(attr), "--no-build"], False)
    return None
