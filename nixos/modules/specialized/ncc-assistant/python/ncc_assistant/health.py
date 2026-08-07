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


def _load_registry(path: Path) -> dict[str, Any]:
    """Load a registry JSON file."""
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def _walk_registry_modules(node: Any, path_prefix: str = "") -> list[dict[str, Any]]:
    """Extract module entries from registry tree."""
    modules: list[dict[str, Any]] = []
    if not isinstance(node, dict):
        return modules

    for key, value in node.items():
        if key.startswith("_"):
            continue
        if isinstance(value, dict):
            if "path" in value:
                modules.append({
                    "name": key,
                    "path": value.get("path", ""),
                    "description": value.get("description", ""),
                    "enabled_default": value.get("enabledDefault", False),
                })
            else:
                modules.extend(_walk_registry_modules(value, f"{path_prefix}{key}/"))

    return modules


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


def config_health_report(settings: Settings) -> HealthReport:
    """
    Generate a configuration health report.
    Uses knowledge registries + optional nix-instantiate check.
    """
    report = HealthReport()
    knowledge_root = settings.knowledge_root

    core_registry = _load_registry(knowledge_root / "modules" / "core-registry.json")
    optional_registry = _load_registry(knowledge_root / "modules" / "optional-registry.json")

    if not core_registry and not optional_registry:
        report.add(HealthFinding(
            level="warning",
            category="knowledge",
            message="No module registries found in knowledge root",
            path=str(knowledge_root),
            suggestion="Ensure knowledge pack is installed",
        ))
        return report

    core_modules = _walk_registry_modules(core_registry)
    optional_modules = _walk_registry_modules(optional_registry)
    all_modules = core_modules + optional_modules
    report.modules_checked = len(all_modules)

    report.add(HealthFinding(
        level="info",
        category="discovery",
        message=f"Found {len(core_modules)} core and {len(optional_modules)} optional modules in registries",
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
