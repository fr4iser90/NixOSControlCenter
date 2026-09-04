#!/usr/bin/env python3
"""100% validation for Hyprland rice apply — hard fail unless every gate passes.

A rice is validated100 only when ALL of:
  - upstream clones and hypr config is found
  - NCC deploy layout + hyprland --verify-config succeeds
  - every require() under the hypr tree resolves on disk
  - every autostart/exec binary resolves on PATH (or absolute path exists)
  - no hardcoded /home/… paths in hypr config tree
  - Lua syntax OK when luac is available (required for .lua rices)
  - apply method is not flake (host flake patch cannot be proven dry-run)

Wallpaper-only rices: 100% if catalog thumbnail is present (NCC only sets wallpaper).
Anything soft / "maybe" → REJECTED (ok=false, validated100=false).
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

RE_REQUIRE = re.compile(r"""require\s*\(\s*["']([^"']+)["']\s*\)""")
RE_EXEC_CMD = re.compile(r"""hl\.exec_cmd\s*\(\s*["']([^"']+)["']""")
RE_EXEC_ONCE = re.compile(r"""exec-(?:once|startup)\s*=\s*([^\n#]+)""", re.I)
RE_BIND_EXEC = re.compile(
    r"""bind\w*\s*=\s*[^,]*,\s*(?:exec|exec-once)\s*,\s*([^\n#]+)""", re.I
)
RE_ANSI = re.compile(r"\x1b\[[0-9;]*m")
RE_HOME = re.compile(r"/home/[^\s\"']+")

# Tokens that are not external programs.
_SHELL_SKIP = {
    "",
    ":",
    "[",
    "[[",
    "true",
    "false",
    "echo",
    "printf",
    "cd",
    "wait",
    "sleep",
    "exit",
    "return",
    "source",
    ".",
    "if",
    "then",
    "else",
    "fi",
    "for",
    "do",
    "done",
    "while",
    "case",
    "esac",
    "exec",  # shell builtin prefix sometimes
}

# Binaries NCC can provide via nixpkgs attr (validate + module install).
# Unmapped missing bins → REJECTED (cannot prove 100%).
NIXPKGS_BIN_ATTR = {
    "foot": "foot",
    "mako": "mako",
    "swaybg": "swaybg",
    "swayidle": "swayidle",
    "swaylock": "swaylock",
    "snapclient": "snapcast",
    "snapserver": "snapcast",
    "wl-paste": "wl-clipboard",
    "wl-copy": "wl-clipboard",
    "waybar": "waybar",
    "hyprpaper": "hyprpaper",
    "hypridle": "hypridle",
    "hyprlock": "hyprlock",
    "kitty": "kitty",
    "alacritty": "alacritty",
    "wezterm": "wezterm",
    "wofi": "wofi",
    "rofi": "rofi",
    "tofi": "tofi",
    "dunst": "dunst",
    "swww": "swww",
    "grim": "grim",
    "slurp": "slurp",
    "wf-recorder": "wf-recorder",
    "playerctl": "playerctl",
    "brightnessctl": "brightnessctl",
    "pamixer": "pamixer",
    "pavucontrol": "pavucontrol",
    "networkmanager_dmenu": "networkmanager_dmenu",
    "nm-applet": "networkmanagerapplet",
    "blueman-applet": "blueman",
    "firefox": "firefox",
    "thunar": "xfce.thunar",
    "mpd": "mpd",
    "mpc": "mpc-cli",
    "notify-send": "libnotify",
    "fyi": "libnotify",
}

DEFAULT_CANDIDATES = [
    "hypr/hyprland.conf",
    ".config/hypr/hyprland.conf",
    "config/hypr/hyprland.conf",
    "hyprland.conf",
    "dots/hyprland.conf",
    "dots/.config/hypr/hyprland.conf",
    "dots/.config/hypr/hyprland.lua",
    "hypr/hyprland.lua",
    ".config/hypr/hyprland.lua",
    "config/hypr/hyprland.lua",
    "compositors/hyprland/hyprland.lua",
    "compositors/hyprland/hyprland.conf",
]


def _load_catalog(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _rice_entry(catalog: dict, rice_id: str) -> dict | None:
    for rice in catalog.get("rices") or []:
        if isinstance(rice, dict) and rice.get("id") == rice_id:
            return rice
    return None


def _discover_hypr(upstream: Path, candidates: list[str]) -> Path | None:
    for rel in candidates:
        p = upstream / rel
        if p.is_file():
            return p
    hits = sorted(
        p
        for p in upstream.rglob("*")
        if p.is_file() and p.name in ("hyprland.conf", "hyprland.lua")
    )
    return hits[0] if hits else None


def _first_token(cmd: str) -> str:
    cmd = cmd.strip().strip('"').strip("'")
    # drop env assignments: FOO=bar cmd
    parts = cmd.split()
    while parts and "=" in parts[0] and not parts[0].startswith("./"):
        parts = parts[1:]
    return parts[0] if parts else ""


def _scan_exec_commands(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    out: list[str] = []
    for m in RE_EXEC_CMD.finditer(text):
        out.append(_first_token(m.group(1)))
    for m in RE_EXEC_ONCE.finditer(text):
        out.append(_first_token(m.group(1)))
    for m in RE_BIND_EXEC.finditer(text):
        out.append(_first_token(m.group(1)))
    return out


def _resolve_lua_module(base_dir: Path, module: str) -> Path | None:
    mod = module.replace(".", "/")
    candidates = [
        base_dir / f"{mod}.lua",
        base_dir / mod / "init.lua",
    ]
    for c in candidates:
        if c.is_file():
            return c
    return None


def _all_requires(files: list[Path]) -> list[tuple[Path, str]]:
    found: list[tuple[Path, str]] = []
    for f in files:
        text = f.read_text(encoding="utf-8", errors="replace")
        for m in RE_REQUIRE.finditer(text):
            found.append((f, m.group(1)))
    return found


def _simulate_ncc_lua_deploy(upstream: Path, hypr: Path, deploy_root: Path) -> Path:
    deploy_root.mkdir(parents=True, exist_ok=True)
    hypr_tree = upstream / hypr.relative_to(upstream).parent
    if hypr_tree.is_dir():
        for item in hypr_tree.iterdir():
            dest = deploy_root / item.name
            if item.is_dir():
                shutil.copytree(item, dest, dirs_exist_ok=True)
            else:
                shutil.copy2(item, dest)
    else:
        shutil.copy2(hypr, deploy_root / hypr.name)
    return deploy_root / hypr.name


def _simulate_ncc_conf_deploy(upstream: Path, hypr: Path, deploy_root: Path) -> Path:
    """Match activation: wrapper conf that sources the collection file."""
    deploy_root.mkdir(parents=True, exist_ok=True)
    entry = deploy_root / "hyprland.conf"
    entry.write_text(
        f"# NCC validate simulate\nsource = {hypr.resolve()}\n",
        encoding="utf-8",
    )
    return entry


def _extract_verify_message(output: str) -> str:
    for line in output.splitlines():
        clean = RE_ANSI.sub("", line).strip()
        if not clean:
            continue
        if clean.startswith("DEBUG"):
            continue
        if "config parsing result" in clean.lower():
            continue
        if "config ok" in clean.lower():
            continue
        if clean.startswith("========"):
            continue
        if ": module '" in clean or ": " in clean:
            parts = clean.split(": ", 1)
            if len(parts) == 2 and parts[1]:
                return parts[1]
        return clean
    return RE_ANSI.sub("", output).strip()[:500] or "hyprland --verify-config failed"


def _hyprland_verify(hyprland_bin: str | None, deployed_entry: Path) -> tuple[bool, str]:
    if not hyprland_bin:
        return False, "hyprland binary required for 100% validation"
    proc = subprocess.run(
        [hyprland_bin, "--verify-config", "-c", str(deployed_entry)],
        capture_output=True,
        text=True,
    )
    combined = (proc.stdout or "") + (proc.stderr or "")
    if proc.returncode == 0:
        return True, "config ok"
    return False, _extract_verify_message(combined)


def _binary_ok(token: str) -> bool:
    if token in _SHELL_SKIP:
        return True
    if token.startswith("~") or token.startswith("$"):
        return False
    if token.startswith("/"):
        return Path(token).exists()
    if "/" in token:  # relative script path
        return False
    return shutil.which(token) is not None


def _resolve_missing_bin(token: str) -> str | None:
    """Return nixpkgs attr that provides token, or None if unmappable."""
    base = Path(token).name if token.startswith("/") else token
    return NIXPKGS_BIN_ATTR.get(base)


def _git_clone(url: str, ref: str, dest: Path) -> None:
    shallow = ["git", "clone", "--depth", "1", "--branch", ref, url, str(dest)]
    if subprocess.run(shallow, capture_output=True).returncode == 0:
        return
    if dest.exists():
        shutil.rmtree(dest)
    # try master then plain depth-1
    for branch in ("master", "main"):
        if dest.exists():
            shutil.rmtree(dest)
        if subprocess.run(
            ["git", "clone", "--depth", "1", "--branch", branch, url, str(dest)],
            capture_output=True,
        ).returncode == 0:
            return
    if dest.exists():
        shutil.rmtree(dest)
    if subprocess.run(["git", "clone", "--depth", "1", url, str(dest)], capture_output=True).returncode != 0:
        raise RuntimeError(f"git clone failed: {url}")


def _sanitize_upstream(upstream: Path) -> int:
    """Import sanitize in-process to avoid packaging cycles."""
    from importlib.util import module_from_spec, spec_from_file_location

    sanitize_path = Path(__file__).with_name("rice-sanitize.py")
    spec = spec_from_file_location("ncc_rice_sanitize", sanitize_path)
    if spec is None or spec.loader is None:
        raise RuntimeError("rice-sanitize.py missing")
    mod = module_from_spec(spec)
    spec.loader.exec_module(mod)
    return int(mod.sanitize_tree(upstream))


def _load_sanitize():
    from importlib.util import module_from_spec, spec_from_file_location

    sanitize_path = Path(__file__).with_name("rice-sanitize.py")
    spec = spec_from_file_location("ncc_rice_sanitize", sanitize_path)
    if spec is None or spec.loader is None:
        raise RuntimeError("rice-sanitize.py missing")
    mod = module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _verify_with_repair(
    *,
    upstream: Path,
    hypr: Path,
    hyprland_bin: str,
    is_lua: bool,
    tmp: Path,
) -> tuple[bool, str, int]:
    """Redeploy + verify; comment obsolete options until config ok."""
    sanitize = _load_sanitize()
    rounds = 0
    last = ""
    for _ in range(30):
        rounds += 1
        deploy_root = tmp / f"deploy-{rounds}"
        if deploy_root.exists():
            shutil.rmtree(deploy_root)
        if is_lua:
            deployed = _simulate_ncc_lua_deploy(upstream, hypr, deploy_root)
        else:
            deployed = _simulate_ncc_conf_deploy(upstream, hypr, deploy_root)
        proc = subprocess.run(
            [hyprland_bin, "--verify-config", "-c", str(deployed)],
            capture_output=True,
            text=True,
        )
        last = (proc.stdout or "") + (proc.stderr or "")
        if proc.returncode == 0:
            return True, "config ok", rounds
        n = sanitize.repair_from_verify_output(upstream, last)
        if n == 0:
            return False, _extract_verify_message(last), rounds
    return False, _extract_verify_message(last), rounds


def _finalize(result: dict) -> dict:
    """100% only when zero errors and zero warnings."""
    if result["errors"] or result["warnings"]:
        result["ok"] = False
        result["validated100"] = False
        result["risk"] = "high"
    else:
        result["ok"] = True
        result["validated100"] = True
        result["risk"] = "none"
    return result


def validate_rice(
    catalog: dict,
    rice_id: str,
    *,
    hyprland_bin: str | None = None,
    luac_bin: str | None = None,
) -> dict:
    rice = _rice_entry(catalog, rice_id)
    result: dict = {
        "rice": rice_id,
        "ok": False,
        "validated100": False,
        "risk": "high",
        "hyprConfig": None,
        "applyMethod": None,
        "checks": [],
        "warnings": [],  # kept for API; any entry rejects 100%
        "errors": [],
        "requiredPackages": [],
    }
    if rice is None:
        result["errors"].append(f"Unknown rice id: {rice_id}")
        return _finalize(result)

    result["applyMethod"] = rice.get("applyMethod") or "reference"
    if not rice.get("applyable"):
        result["errors"].append("Rice is reference-only / not in applyable store")
        return _finalize(result)

    method = result["applyMethod"]

    if method == "wallpaper":
        if rice.get("thumbnailHash"):
            result["checks"].append("Wallpaper-only rice with catalog thumbnail — NCC apply scope covered")
            return _finalize(result)
        result["errors"].append("Wallpaper rice missing thumbnailHash")
        return _finalize(result)

    if method == "flake":
        result["errors"].append(
            "Flake rice patches host flake.nix — cannot prove 100% dry-run; apply blocked"
        )
        return _finalize(result)

    if method != "dotfiles":
        result["errors"].append(f"Apply method '{method}' is not 100%-validatable")
        return _finalize(result)

    dotfiles = rice.get("dotfiles") or {}
    clone_url = str(dotfiles.get("cloneUrl") or "")
    ref = str(dotfiles.get("ref") or "main")
    if not clone_url:
        result["errors"].append("No dotfiles clone URL in catalog")
        return _finalize(result)

    candidates = list(dotfiles.get("hyprCandidates") or DEFAULT_CANDIDATES)
    tmp = Path(tempfile.mkdtemp(prefix="ncc-hyprland-validate-"))
    try:
        upstream = tmp / "upstream"
        try:
            _git_clone(clone_url, ref, upstream)
        except RuntimeError as e:
            result["errors"].append(str(e))
            return _finalize(result)
        result["checks"].append(f"Cloned {clone_url} (ref {ref})")

        n_sanitized = _sanitize_upstream(upstream)
        result["checks"].append(f"Sanitized upstream tree ({n_sanitized} files rewritten)")

        hypr = _discover_hypr(upstream, candidates)
        if hypr is None:
            result["errors"].append("No hyprland.conf / hyprland.lua found in upstream repo")
            return _finalize(result)

        rel = hypr.relative_to(upstream).as_posix()
        result["hyprConfig"] = rel
        result["checks"].append(f"Hypr config: {rel}")

        hypr_tree = hypr.parent
        tree_files = [
            p
            for p in hypr_tree.rglob("*")
            if p.is_file() and p.suffix in (".lua", ".conf", ".hl")
        ]

        # Hardcoded home paths anywhere in hypr tree → reject
        for tf in tree_files:
            text = tf.read_text(encoding="utf-8", errors="replace")
            homes = RE_HOME.findall(text)
            if homes:
                result["errors"].append(
                    f"Hardcoded home path in {tf.relative_to(upstream)}: {homes[0]}"
                )

        deploy_root = tmp / "deploy"
        if hypr.suffix == ".lua":
            if not luac_bin:
                result["errors"].append("luac required for 100% Lua validation")
            else:
                for lf in sorted(hypr_tree.rglob("*.lua")):
                    proc = subprocess.run(
                        [luac_bin, "-p", str(lf)],
                        capture_output=True,
                        text=True,
                    )
                    if proc.returncode != 0:
                        err = (proc.stderr or proc.stdout or "syntax error").strip()
                        result["errors"].append(
                            f"Lua syntax error in {lf.relative_to(upstream)}: {err}"
                        )
                    else:
                        result["checks"].append(f"Lua syntax ok: {lf.relative_to(upstream)}")

            deploy_root = tmp / "deploy"
            deployed = _simulate_ncc_lua_deploy(upstream, hypr, deploy_root)
            requires = _all_requires(list(hypr_tree.rglob("*.lua")))
            for src, modname in requires:
                resolved = _resolve_lua_module(deployed.parent, modname)
                if resolved is None:
                    resolved = _resolve_lua_module(src.parent, modname)
                if resolved is None:
                    result["errors"].append(
                        f"Missing Lua module require('{modname}') from {src.relative_to(upstream)}"
                    )
                else:
                    result["checks"].append(f"require('{modname}') → {resolved.name}")

            if not hyprland_bin:
                result["errors"].append("hyprland binary required for 100% validation")
            elif not result["errors"]:
                verify_ok, verify_msg, rounds = _verify_with_repair(
                    upstream=upstream,
                    hypr=hypr,
                    hyprland_bin=hyprland_bin,
                    is_lua=True,
                    tmp=tmp,
                )
                if verify_ok:
                    result["checks"].append(
                        f"NCC deploy + hyprland --verify-config: {verify_msg} (repair rounds={rounds})"
                    )
                else:
                    result["errors"].append(
                        f"hyprland --verify-config FAILED (login would break): {verify_msg}"
                    )
        else:
            result["checks"].append("Classic hyprland.conf — simulated NCC source wrapper")
            if not hyprland_bin:
                result["errors"].append("hyprland binary required for 100% validation")
            else:
                verify_ok, verify_msg, rounds = _verify_with_repair(
                    upstream=upstream,
                    hypr=hypr,
                    hyprland_bin=hyprland_bin,
                    is_lua=False,
                    tmp=tmp,
                )
                if verify_ok:
                    result["checks"].append(
                        f"NCC deploy + hyprland --verify-config: {verify_msg} (repair rounds={rounds})"
                    )
                else:
                    result["errors"].append(
                        f"hyprland --verify-config FAILED (login would break): {verify_msg}"
                    )

        # Exec / autostart binaries — all must resolve or map to nixpkgs
        exec_cmds: list[str] = []
        scan_paths = list(hypr_tree.rglob("*.lua")) + list(hypr_tree.rglob("*.conf"))
        if hypr not in scan_paths:
            scan_paths.append(hypr)
        for sp in scan_paths:
            exec_cmds.extend(_scan_exec_commands(sp))
        exec_cmds = sorted({c for c in exec_cmds if c and c not in _SHELL_SKIP})
        needed_attrs: list[str] = []
        for c in exec_cmds:
            if _binary_ok(c):
                result["checks"].append(f"exec binary ok: {c}")
                continue
            attr = _resolve_missing_bin(c)
            if attr:
                needed_attrs.append(attr)
                result["checks"].append(
                    f"exec binary via nixpkgs.{attr}: {Path(c).name} (NCC will install)"
                )
            else:
                result["errors"].append(
                    f"Missing required exec/autostart binary: {c} "
                    f"(not on PATH and not in NCC nixpkgs map — rice not 100%)"
                )
        result["requiredPackages"] = sorted(set(needed_attrs))

        return _finalize(result)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def _print_human(report: dict) -> None:
    rice = report.get("rice") or "?"
    v100 = bool(report.get("validated100"))
    print(f"Rice validate (100% gate): {rice}")
    print(f"validated100: {'YES' if v100 else 'NO'}")
    print(f"ok: {'yes' if report.get('ok') else 'no'}  risk: {report.get('risk', 'high')}")
    if report.get("hyprConfig"):
        print(f"Config: {report['hyprConfig']}")
    if report.get("applyMethod"):
        print(f"Method: {report['applyMethod']}")
    print()
    for line in report.get("checks") or []:
        print(f"  ✓ {line}")
    for line in report.get("warnings") or []:
        print(f"  ⚠ {line}")
    for line in report.get("errors") or []:
        print(f"  ✗ {line}")
    print()
    if v100:
        print("VALIDATED 100% — apply allowed.")
    else:
        print("REJECTED — not 100%. Apply blocked until every gate passes.")


def main() -> int:
    p = argparse.ArgumentParser(description="100% validate Hyprland rice (hard gate)")
    p.add_argument("rice_id")
    p.add_argument("--catalog", required=True, help="Path to ncc-hyprland-catalog.json")
    p.add_argument("--hyprland", default=None, help="Path to hyprland binary")
    p.add_argument("--luac", default=None, help="Path to luac binary")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()

    hyprland_bin = args.hyprland or shutil.which("hyprland")
    luac_bin = args.luac or shutil.which("luac")
    catalog = _load_catalog(Path(args.catalog))
    report = validate_rice(
        catalog, args.rice_id, hyprland_bin=hyprland_bin, luac_bin=luac_bin
    )

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        _print_human(report)

    return 0 if report.get("validated100") else 1


if __name__ == "__main__":
    sys.exit(main())
