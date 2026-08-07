"""Lightweight probes (no LLM) with optional agent escalation on thresholds."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from dataclasses import dataclass, asdict, field
from pathlib import Path
from typing import Any


@dataclass
class DiskNixProbeResult:
    ok: bool = True
    root_pct: float | None = None
    root_used_gb: float | None = None
    root_total_gb: float | None = None
    nix_store_gb: float | None = None
    generation_count: int | None = None
    over_threshold: bool = False
    threshold_pct: float = 85.0
    hints: list[str] = field(default_factory=list)
    raw: dict[str, Any] = field(default_factory=dict)
    error: str | None = None

    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        return {k: v for k, v in d.items() if v is not None}


def _df_path(path: str = "/") -> dict[str, float] | None:
    try:
        usage = shutil.disk_usage(path)
        total = usage.total
        used = usage.used
        if total <= 0:
            return None
        return {
            "total_gb": round(total / (1024**3), 2),
            "used_gb": round(used / (1024**3), 2),
            "free_gb": round(usage.free / (1024**3), 2),
            "pct": round(100.0 * used / total, 1),
        }
    except OSError:
        return None


def _dir_size_gb(path: Path, *, timeout_sec: float = 5.0) -> float | None:
    if not path.is_dir():
        return None
    # Prefer cheap df when path is its own mountpoint
    df = _df_path(str(path))
    if df is not None:
        # If /nix or /nix/store is a separate filesystem, used_gb is enough
        root_df = _df_path("/")
        if root_df and abs(df["total_gb"] - root_df["total_gb"]) > 0.5:
            return df["used_gb"]
    # Avoid scanning huge stores: only try a short du, otherwise skip
    if shutil.which("du"):
        try:
            proc = subprocess.run(
                ["du", "-sb", "--max-depth=0", str(path)],
                capture_output=True,
                text=True,
                timeout=timeout_sec,
                check=False,
            )
            if proc.returncode == 0 and proc.stdout.strip():
                nbytes = int(proc.stdout.split()[0])
                return round(nbytes / (1024**3), 2)
        except (OSError, ValueError, subprocess.TimeoutExpired):
            return None
    return None


def _count_system_generations(limit: int = 200) -> int | None:
    profile = Path("/nix/var/nix/profiles")
    if not profile.is_dir():
        return None
    try:
        links = list(profile.glob("system-*-link"))
        return min(len(links), limit)
    except OSError:
        return None


def run_disk_nix_probe(
    *,
    threshold_pct: float = 85.0,
    measure_store: bool = False,
) -> DiskNixProbeResult:
    """
    Collect disk / Nix metrics without calling an LLM.

    By default does NOT `du /nix/store` (can take minutes). Set measure_store=True
    to attempt a short-timeout size estimate, or rely on df when /nix is separate.
    """
    result = DiskNixProbeResult(threshold_pct=threshold_pct)
    root = _df_path("/")
    if root is None:
        result.ok = False
        result.error = "Could not read disk usage for /"
        return result

    result.ok = True
    result.root_pct = root["pct"]
    result.root_used_gb = root["used_gb"]
    result.root_total_gb = root["total_gb"]
    result.raw["root"] = root

    # Cheap: df for /nix if present
    nix_df = _df_path("/nix")
    nix_pct: float | None = None
    if nix_df is not None:
        result.raw["nix_df"] = nix_df
        result.nix_store_gb = nix_df["used_gb"]
        nix_pct = nix_df["pct"]
        result.raw["nix_pct"] = nix_pct

    if measure_store and result.nix_store_gb is None:
        nix_gb = _dir_size_gb(Path("/nix/store"), timeout_sec=8.0)
        if nix_gb is not None:
            result.nix_store_gb = nix_gb
            result.raw["nix_store_gb"] = nix_gb

    gens = _count_system_generations()
    if gens is not None:
        result.generation_count = gens
        result.raw["generation_count"] = gens

    root_over = (result.root_pct or 0) >= threshold_pct
    nix_over = nix_pct is not None and nix_pct >= threshold_pct
    result.over_threshold = root_over or nix_over
    result.raw["root_over"] = root_over
    result.raw["nix_over"] = nix_over

    if result.over_threshold:
        parts = []
        if root_over:
            parts.append(f"root {result.root_pct}%")
        if nix_over:
            parts.append(f"/nix {nix_pct}%")
        result.hints.append(
            f"Disk pressure: {', '.join(parts)} "
            f"(threshold {threshold_pct}%). Review Nix GC options."
        )
    else:
        nix_txt = f", /nix {nix_pct}%" if nix_pct is not None else ""
        result.hints.append(
            f"OK: root {result.root_pct}%{nix_txt} "
            f"(threshold {threshold_pct}%)."
        )

    if result.generation_count and result.generation_count > 20:
        result.hints.append(
            f"{result.generation_count} system profile links found — "
            "old generations may free space after careful review."
        )
    if result.nix_store_gb is not None:
        result.hints.append(f"/nix usage ≈ {result.nix_store_gb} GiB")
    else:
        result.hints.append(
            "/nix/store size not measured (use measure_store or separate /nix mount)."
        )

    return result


def escalate_disk_probe(
    probe: DiskNixProbeResult,
    *,
    playbook: str = "disk-nix-gc-advisor",
    force: bool = False,
) -> dict[str, Any]:
    """
    If over threshold (or force), run the advisor playbook via agent.
    Otherwise only notify a short OK summary.
    """
    from .notifications import notify_agent_event

    summary = (
        f"root={probe.root_pct}% "
        f"nix_store={probe.nix_store_gb}GiB "
        f"gens={probe.generation_count}"
    )

    if not probe.over_threshold and not force:
        notify_agent_event("Disk probe OK", summary, urgency="low")
        return {
            "ok": True,
            "escalated": False,
            "probe": probe.to_dict(),
            "message": "Under threshold — no agent run",
        }

    notify_agent_event(
        "Disk probe: threshold exceeded",
        summary + " — starting GC advisor (read-only)",
        urgency="critical",
    )

    from .agent import run_agent
    from .auth import with_cached_credentials
    from .config import Settings
    from .playbooks import get_playbook

    pb = get_playbook(playbook)
    settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
    goal = pb.goal if pb else (
        "Disk/Nix usage is high. Use disk_nix_report and list_boot_generations. "
        "Summarize safe cleanup options. Do NOT delete or run GC. dry-run only."
    )
    events = []
    for ev in run_agent(
        goal,
        settings,
        max_steps=(pb.max_steps if pb and pb.max_steps else 16),
        dry_run=True if pb is None else pb.dry_run,
        profile=(pb.profile if pb else "read-only") or "read-only",
        playbook=playbook if pb else None,
    ):
        events.append(ev)

    last = events[-1] if events else {}
    return {
        "ok": True,
        "escalated": True,
        "probe": probe.to_dict(),
        "playbook": playbook,
        "event_count": len(events),
        "last_kind": last.get("kind"),
    }


def run_disk_probe_and_maybe_escalate(
    *,
    threshold_pct: float = 85.0,
    escalate: bool = True,
    force: bool = False,
    playbook: str = "disk-nix-gc-advisor",
) -> dict[str, Any]:
    probe = run_disk_nix_probe(threshold_pct=threshold_pct)
    out: dict[str, Any] = {"ok": probe.ok, "probe": probe.to_dict()}
    if not probe.ok:
        return out
    if not escalate:
        return out
    return escalate_disk_probe(probe, playbook=playbook, force=force)
