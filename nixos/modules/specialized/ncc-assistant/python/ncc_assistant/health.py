"""Configuration health report using knowledge registries."""

from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .config import Settings


@dataclass
class HealthFinding:
    """A single health check finding."""
    level: str  # info | warning | error
    category: str
    message: str
    path: str | None = None
    suggestion: str | None = None

    def to_dict(self) -> dict[str, Any]:
        d = {
            "level": self.level,
            "category": self.category,
            "message": self.message,
        }
        if self.path:
            d["path"] = self.path
        if self.suggestion:
            d["suggestion"] = self.suggestion
        return d


@dataclass
class HealthReport:
    """Complete health report."""
    findings: list[HealthFinding] = field(default_factory=list)
    modules_checked: int = 0
    errors: int = 0
    warnings: int = 0
    info: int = 0

    def add(self, finding: HealthFinding) -> None:
        self.findings.append(finding)
        if finding.level == "error":
            self.errors += 1
        elif finding.level == "warning":
            self.warnings += 1
        else:
            self.info += 1

    def to_dict(self) -> dict[str, Any]:
        return {
            "modules_checked": self.modules_checked,
            "errors": self.errors,
            "warnings": self.warnings,
            "info": self.info,
            "findings": [f.to_dict() for f in self.findings],
        }


def _load_json(path: Path) -> dict[str, Any]:
    """Load a JSON file or return {}."""
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def _check_nix_instantiate(nixos_dir: str) -> tuple[bool, str]:
    """Try to instantiate the NixOS config to check for errors."""
    flake_path = Path(nixos_dir)
    if not flake_path.is_dir():
        return False, f"NIXOS_DIR not found: {nixos_dir}"

    try:
        hostname = Path("/etc/hostname").read_text(encoding="utf-8").strip() or "nixos"
    except OSError:
        hostname = "nixos"

    cmd = [
        "nix-instantiate",
        "--eval",
        "--strict",
        "-E",
        f'(builtins.tryEval (import {nixos_dir}/flake.nix).nixosConfigurations.{hostname}).success or true',
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        if result.returncode != 0:
            return False, result.stderr[:500]
        return True, ""
    except subprocess.TimeoutExpired:
        return False, "Evaluation timed out"
    except OSError as e:
        return False, str(e)


def _load_live_modules() -> tuple[list[dict[str, Any]], str]:
    """Ask ncc modules list --json (runtime discovery). Empty if unavailable."""
    import json
    import shutil
    import subprocess

    cmd = None
    if shutil.which("ncc"):
        cmd = ["ncc", "modules", "list", "--json"]
    elif shutil.which("ncc-modules-discover"):
        cmd = ["ncc-modules-discover"]
    if not cmd:
        return [], "none"
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=30, check=False
        )
        if proc.returncode != 0 or not (proc.stdout or "").strip():
            return [], "none"
        data = json.loads(proc.stdout)
    except (OSError, json.JSONDecodeError, subprocess.TimeoutExpired):
        return [], "none"

    if isinstance(data, list):
        rows = data
    elif isinstance(data, dict):
        rows = data.get("modules") or data.get("data") or []
    else:
        rows = []

    modules: list[dict[str, Any]] = []
    for m in rows:
        if not isinstance(m, dict):
            continue
        name = m.get("name") or m.get("id") or ""
        if not name:
            continue
        cat = str(m.get("category") or m.get("domain") or "")
        kind = (
            "core"
            if cat.startswith("core") or m.get("scope") == "core"
            else "optional"
        )
        modules.append(
            {
                "name": name,
                "path": m.get("path") or m.get("relPath") or "",
                "description": m.get("description") or name,
                "enabled_default": m.get("defaultEnabled", kind == "core"),
                "kind": m.get("kind") or kind,
            }
        )
    return modules, "ncc-modules-discover"


def config_health_report(settings: Settings) -> HealthReport:
    """
    Generate a configuration health report.
    Module inventory = live ``ncc modules list`` only (no packaged JSON).
    """
    report = HealthReport()
    knowledge_root = settings.knowledge_root

    all_modules, source = _load_live_modules()

    if not all_modules:
        report.add(HealthFinding(
            level="warning",
            category="knowledge",
            message="Live module discovery failed",
            path=str(knowledge_root),
            suggestion="Ensure `ncc modules list --json` works on this host",
        ))
        return report

    core_n = sum(1 for m in all_modules if m.get("kind") == "core" or str(m.get("path", "")).startswith("nixos/core/"))
    optional_n = len(all_modules) - core_n
    report.modules_checked = len(all_modules)

    report.add(HealthFinding(
        level="info",
        category="discovery",
        message=f"Modules from {source}: {len(all_modules)} "
        f"(core≈{core_n}, optional≈{optional_n})",
        path=str(knowledge_root),
    ))

    nixos_dir = Path(settings.nixos_dir)
    if not nixos_dir.is_dir():
        report.add(HealthFinding(
            level="error",
            category="filesystem",
            message=f"NIXOS_DIR does not exist: {nixos_dir}",
            suggestion="Set correct NIXOS_DIR or ensure the directory exists",
        ))
    else:
        flake_nix = nixos_dir / "flake.nix"
        if not flake_nix.is_file():
            report.add(HealthFinding(
                level="warning",
                category="filesystem",
                message="flake.nix not found in NIXOS_DIR",
                path=str(nixos_dir),
                suggestion="This may not be a flake-based NixOS configuration",
            ))
        else:
            report.add(HealthFinding(
                level="info",
                category="filesystem",
                message=f"Found flake.nix at {flake_nix}",
            ))

    index_path = knowledge_root / "index.json"
    if not index_path.is_file():
        report.add(HealthFinding(
            level="warning",
            category="knowledge",
            message="Knowledge index.json not found",
            path=str(knowledge_root),
            suggestion="Run knowledge pack builder to generate index",
        ))
    else:
        try:
            index = json.loads(index_path.read_text(encoding="utf-8"))
            skills = len(index.get("skills", []))
            contexts = len(index.get("contexts", []))
            domains = len(index.get("domains", []))
            report.add(HealthFinding(
                level="info",
                category="knowledge",
                message=f"Knowledge index: {skills} skills, {contexts} contexts, {domains} domains",
            ))
        except (OSError, json.JSONDecodeError) as e:
            report.add(HealthFinding(
                level="warning",
                category="knowledge",
                message=f"Failed to parse knowledge index: {e}",
                path=str(index_path),
            ))

    if not settings.api_key:
        report.add(HealthFinding(
            level="warning",
            category="auth",
            message="No API key configured",
            suggestion="Set API key via env, file, or cached credentials",
        ))

    if settings.api == "openai-compatible":
        report.add(HealthFinding(
            level="info",
            category="api",
            message=f"Using OpenAI-compatible endpoint: {settings.endpoint}",
        ))
    elif settings.api == "anthropic":
        report.add(HealthFinding(
            level="info",
            category="api",
            message="Using Anthropic API",
        ))

    return report
