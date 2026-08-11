"""Discover install device-targets from host-blueprints (SSOT).

Any file under setup/modes/host-blueprints/ with:

  deviceTarget = {
    enable = true;
    label = "…";
    description = "…";   # optional
    match = { … };       # optional detection rules
  };

is a device target. No wiring in setup-options / detect scripts.

Match (all optional; arch is AND, probes are OR):
  arch = [ "aarch64" "arm64" ];
  lspci / lscpu / cpuinfo / model / compatible = [ "substr" … ];
  filesAny = [ "/path" … ];          # any existing file → hit
  textAny = [ "substr" … ];          # search tegra + config + uname + probes
"""

from __future__ import annotations

import argparse
import os
import platform
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


@dataclass
class DeviceTarget:
    blueprint: str  # filename under host-blueprints/
    label: str
    description: str = ""
    arch: list[str] = field(default_factory=list)
    lspci: list[str] = field(default_factory=list)
    lscpu: list[str] = field(default_factory=list)
    cpuinfo: list[str] = field(default_factory=list)
    model: list[str] = field(default_factory=list)
    compatible: list[str] = field(default_factory=list)
    files_any: list[str] = field(default_factory=list)
    text_any: list[str] = field(default_factory=list)


def host_blueprints_dir() -> Path:
    env = (os.environ.get("NCC_HOST_BLUEPRINTS") or "").strip()
    if env and Path(env).is_dir():
        return Path(env)
    root = (os.environ.get("SCRIPT_ROOT") or "").strip()
    if root:
        cand = Path(root) / "setup" / "modes" / "host-blueprints"
        if cand.is_dir():
            return cand
    # Source tree: …/install-wizard/ui/gui → …/scripts/setup/modes/host-blueprints
    here = Path(__file__).resolve().parent
    for cand in (
        here.parents[1] / "scripts" / "setup" / "modes" / "host-blueprints",
        here.parents[2] / "scripts" / "setup" / "modes" / "host-blueprints",
    ):
        if cand.is_dir():
            return cand
    raise FileNotFoundError(
        "host-blueprints dir not found — set SCRIPT_ROOT or NCC_HOST_BLUEPRINTS"
    )


def _read_text(path: str | Path) -> str:
    try:
        return Path(path).read_text(errors="ignore")
    except OSError:
        return ""


def _cmd_out(argv: list[str]) -> str:
    try:
        return subprocess.check_output(argv, stderr=subprocess.DEVNULL, text=True)
    except (OSError, subprocess.CalledProcessError):
        return ""


def _extract_attrset(text: str, name: str) -> str | None:
    """Return body inside `name = { … }` (brace-balanced), or None."""
    m = re.search(rf"\b{re.escape(name)}\s*=\s*\{{", text)
    if not m:
        return None
    i = m.end()
    depth = 1
    while i < len(text) and depth:
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    if depth != 0:
        return None
    return text[m.end() : i - 1]


def _parse_bool(body: str, key: str, default: bool = False) -> bool:
    m = re.search(rf"\b{re.escape(key)}\s*=\s*(true|false)\s*;", body)
    if not m:
        return default
    return m.group(1) == "true"


def _parse_str(body: str, key: str, default: str = "") -> str:
    m = re.search(rf'\b{re.escape(key)}\s*=\s*"([^"]*)"\s*;', body)
    return m.group(1) if m else default


def _parse_str_list(body: str, key: str) -> list[str]:
    m = re.search(rf"\b{re.escape(key)}\s*=\s*\[(.*?)\]\s*;", body, re.S)
    if not m:
        return []
    return re.findall(r'"([^"]*)"', m.group(1))


def _parse_target(path: Path) -> DeviceTarget | None:
    text = _read_text(path)
    body = _extract_attrset(text, "deviceTarget")
    if body is None:
        return None
    if not _parse_bool(body, "enable", default=False):
        return None
    label = _parse_str(body, "label").strip()
    if not label:
        return None
    match_body = _extract_attrset(body, "match") or ""
    return DeviceTarget(
        blueprint=path.name,
        label=label,
        description=_parse_str(body, "description").strip(),
        arch=_parse_str_list(match_body, "arch"),
        lspci=_parse_str_list(match_body, "lspci"),
        lscpu=_parse_str_list(match_body, "lscpu"),
        cpuinfo=_parse_str_list(match_body, "cpuinfo"),
        model=_parse_str_list(match_body, "model"),
        compatible=_parse_str_list(match_body, "compatible"),
        files_any=_parse_str_list(match_body, "filesAny"),
        text_any=_parse_str_list(match_body, "textAny"),
    )


def discover_device_targets(blueprints_dir: Path | None = None) -> list[DeviceTarget]:
    d = blueprints_dir or host_blueprints_dir()
    out: list[DeviceTarget] = []
    for path in sorted(d.iterdir(), key=lambda p: p.name.lower()):
        if not path.is_file() or path.name.startswith("."):
            continue
        # skip empty / non-nix-like stubs
        if path.stat().st_size == 0:
            continue
        t = _parse_target(path)
        if t:
            out.append(t)
    return out


def _any_substr(haystack: str, needles: Iterable[str]) -> bool:
    h = haystack.lower()
    return any(n.lower() in h for n in needles if n)


def target_matches(
    t: DeviceTarget,
    *,
    machine: str | None = None,
    lspci: str | None = None,
    lscpu: str | None = None,
    cpuinfo: str | None = None,
    model: str | None = None,
    compatible: str | None = None,
    text_blob: str | None = None,
) -> bool:
    """Evaluate match rules against probe strings (caller may inject for tests)."""
    machine = (machine if machine is not None else platform.machine()).lower()
    if t.arch:
        arch_ok = any(
            machine == a.lower()
            or (a.lower() in ("arm64", "aarch64") and machine in ("arm64", "aarch64"))
            for a in t.arch
        )
        if not arch_ok:
            return False

    # No probe rules → listed only, never auto-matched
    probes_defined = any(
        [
            t.lspci,
            t.lscpu,
            t.cpuinfo,
            t.model,
            t.compatible,
            t.files_any,
            t.text_any,
        ]
    )
    if not probes_defined:
        return False

    lspci = lspci if lspci is not None else _cmd_out(["lspci"])
    lscpu = lscpu if lscpu is not None else _cmd_out(["lscpu"])
    cpuinfo = cpuinfo if cpuinfo is not None else _read_text("/proc/cpuinfo")
    model = (
        model
        if model is not None
        else _read_text("/sys/firmware/devicetree/base/model").replace("\x00", "")
    )
    compatible = (
        compatible
        if compatible is not None
        else _read_text("/sys/firmware/devicetree/base/compatible").replace("\x00", " ")
    )
    if text_blob is None:
        text_blob = "\n".join(
            [
                _read_text("/etc/nv_tegra_release"),
                _read_text("/etc/nixos/configuration.nix"),
                " ".join(platform.uname()),
                lspci,
                lscpu,
                cpuinfo,
                model,
                compatible,
            ]
        )

    if t.files_any and any(Path(p).exists() for p in t.files_any):
        return True
    if t.lspci and _any_substr(lspci, t.lspci):
        return True
    if t.lscpu and _any_substr(lscpu, t.lscpu):
        return True
    if t.cpuinfo and _any_substr(cpuinfo, t.cpuinfo):
        return True
    if t.model and _any_substr(model, t.model):
        return True
    if t.compatible and _any_substr(compatible, t.compatible):
        return True
    if t.text_any and _any_substr(text_blob, t.text_any):
        return True
    return False


def match_device_targets(
    targets: list[DeviceTarget] | None = None,
) -> list[DeviceTarget]:
    force = (os.environ.get("NCC_FORCE_DEVICE_TARGETS") or "").strip()
    targets = list(targets if targets is not None else discover_device_targets())
    if force:
        wanted = {x.strip() for x in force.split(",") if x.strip()}
        return [t for t in targets if t.label in wanted]
    return [t for t in targets if target_matches(t)]


def cmd_list(_: argparse.Namespace) -> int:
    for t in discover_device_targets():
        print(f"{t.label}\t{t.blueprint}\t{t.description}")
    return 0


def cmd_match(_: argparse.Namespace) -> int:
    for t in match_device_targets():
        print(t.label)
    return 0


def cmd_export_bash(_: argparse.Namespace) -> int:
    """Print bash that fills DEVICE_TARGETS + DEVICE_BLUEPRINT_MAP (+ optional descs)."""
    targets = discover_device_targets()
    print("DEVICE_TARGETS=(")
    for t in targets:
        print(f"  {repr(t.label)}")
    print(")")
    print("declare -g -A DEVICE_BLUEPRINT_MAP=()")
    for t in targets:
        print(f"DEVICE_BLUEPRINT_MAP[{repr(t.label)}]={repr(t.blueprint)}")
    print("declare -g -A DEVICE_TARGET_DESCRIPTIONS=()")
    for t in targets:
        if t.description:
            print(
                f"DEVICE_TARGET_DESCRIPTIONS[{repr(t.label.lower())}]={repr(t.description)}"
            )
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list", help="label\\tblueprint\\tdescription").set_defaults(
        func=cmd_list
    )
    sub.add_parser("match", help="matched labels (one per line)").set_defaults(
        func=cmd_match
    )
    sub.add_parser("export-bash", help="bash snippets for DEVICE_* arrays").set_defaults(
        func=cmd_export_bash
    )
    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
