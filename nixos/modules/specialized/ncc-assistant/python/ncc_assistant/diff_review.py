"""Diff review helpers for proposed Nix config patches."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable

from .runtime import ToolRuntime


@dataclass
class PatchProposal:
    module_path: str
    proposed_nix: str
    diff: str = ""
    current: str = ""


def build_proposal(runtime: ToolRuntime, module_path: str, proposed_nix: str) -> PatchProposal:
    preview = runtime.propose_config_patch(module_path, proposed_nix)
    return PatchProposal(
        module_path=module_path,
        proposed_nix=proposed_nix,
        diff=str(preview.get("diff") or ""),
        current=str(preview.get("current") or ""),
    )


def apply_selected(
    runtime: ToolRuntime,
    proposals: list[PatchProposal],
    selected_paths: list[str],
) -> list[dict[str, Any]]:
    """Apply selected module paths. Caller must have confirm_hook / policy set."""
    out: list[dict[str, Any]] = []
    wanted = set(selected_paths)
    for p in proposals:
        if p.module_path not in wanted:
            continue
        result = runtime.apply_module_config(p.module_path, p.proposed_nix, confirm=True)
        out.append({"module_path": p.module_path, **result})
    return out
