#!/usr/bin/env python3
"""Sanitize upstream hypr trees for NCC deploy + current Hyprland verify-config."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

RE_HOME = re.compile(r"/home/[A-Za-z0-9._-]+(/[^\s\"']*)?")
RE_NIX_BIN = re.compile(r"/nix/store/[a-z0-9]+-[^/\s\"']+/bin/([A-Za-z0-9._+-]+)")
RE_SOURCE_TILDE_HYPR = re.compile(
    r"(?P<prefix>source\s*=\s*)(?P<root>~/.config/hypr/|\$HOME/\.config/hypr/)(?P<rest>[^\s#]+)",
    re.IGNORECASE,
)
RE_SOURCE_REL = re.compile(
    r"^(?P<prefix>\s*source\s*=\s*)(?P<path>\./[^\s#]+|[^\s#/~$][^\s#]*)",
    re.MULTILINE | re.IGNORECASE,
)
RE_ANSI = re.compile(r"\x1b\[[0-9;]*m")

RE_OPT_ERR = re.compile(r"config option <([^>]+)> does not exist", re.I)
RE_DISP_ERR = re.compile(r'Invalid dispatcher(?:, requested)?[:\s]+"?([A-Za-z0-9_-]+)"?', re.I)
RE_FIELD_ERR = re.compile(r"invalid field ([A-Za-z0-9_-]+):", re.I)
RE_FIELD_TYPE_ERR = re.compile(r"invalid field type ([A-Za-z0-9_-]+)", re.I)
RE_DEPRECATED = re.compile(r"\b(windowrulev2|layerrule)\b is deprecated", re.I)
RE_SOURCE_HOME_VAR = re.compile(
    r"(?P<prefix>exec-(?:once|startup)\s*=\s*)(?P<path>\$HOME/\.config/hypr/[^\s#]+|~/.config/hypr/[^\s#]+)",
    re.IGNORECASE,
)

OBSOLETE_OPTION = re.compile(
    r"^(?P<indent>\s*)(?P<key>"
    r"general:sensitivity|general:apply_sens_to_raw|sensitivity|"
    r"decoration:drop_shadow|decoration:shadow_range|decoration:shadow_render_power|"
    r"decoration:col\.shadow|decoration:col\.shadow_inactive|"
    r"decoration:dim_around|"
    r"dwindle:pseudotile|dwindle:force_split|dwindle:preserve_split|"
    r"dwindle:special_scale_factor|dwindle:split_width_multiplier|"
    r"master:new_is_master|master:new_on_top|"
    r"misc:force_default_wallpaper"
    r")\s*=",
    re.MULTILINE | re.IGNORECASE,
)

RE_TOGGLESPLIT = re.compile(
    r"(?P<head>bind\w*\s*=\s*[^,]*,\s*[^,]*,\s*)togglesplit(?P<tail>\s*,?)",
    re.IGNORECASE,
)

TEXT_SUFFIXES = {".conf", ".lua", ".hl", ".txt", ".css", ".sh"}


def _find_hypr_root(start: Path, collection_root: Path) -> Path | None:
    cur = start if start.is_dir() else start.parent
    root = collection_root.resolve()
    while True:
        if (cur / "hyprland.conf").is_file() or (cur / "hyprland.lua").is_file():
            return cur
        if cur.resolve() == root or cur.parent == cur:
            break
        cur = cur.parent
    for cand in collection_root.rglob("hyprland.conf"):
        return cand.parent
    for cand in collection_root.rglob("hyprland.lua"):
        return cand.parent
    return None


def _resolve_hypr_source(hypr_root: Path, rest: str) -> Path | None:
    rest = rest.strip().strip('"').strip("'")
    cand = hypr_root / rest
    if cand.exists():
        return cand
    cand2 = hypr_root / Path(rest).name
    if cand2.exists():
        return cand2
    return None


def _rewrite_text(text: str, *, collection_root: Path, file_path: Path) -> str:
    hypr_root = _find_hypr_root(file_path, collection_root) or file_path.parent
    text = RE_NIX_BIN.sub(r"\1", text)

    def home_sub(m: re.Match[str]) -> str:
        rest = m.group(1) or ""
        if not rest:
            return ""
        parts = rest.strip("/").split("/")
        for i, p in enumerate(parts):
            if p in (".config", "config", "hypr", "dots", "compositors"):
                return "/".join(parts[i:])
        return parts[-1]

    text = RE_HOME.sub(home_sub, text)

    def tilde_source(m: re.Match[str]) -> str:
        resolved = _resolve_hypr_source(hypr_root, m.group("rest"))
        if resolved is None:
            return m.group(0)
        return f"{m.group('prefix')}{resolved}"

    text = RE_SOURCE_TILDE_HYPR.sub(tilde_source, text)

    def home_exec(m: re.Match[str]) -> str:
        raw = m.group("path").replace("$HOME/.config/hypr/", "").replace("~/.config/hypr/", "")
        resolved = _resolve_hypr_source(hypr_root, raw)
        if resolved is None:
            return f"{m.group('prefix')}# NCC-sanitize: missing {m.group('path')}"
        return f"{m.group('prefix')}{resolved}"

    text = RE_SOURCE_HOME_VAR.sub(home_exec, text)

    def rel_source(m: re.Match[str]) -> str:
        raw = m.group("path").strip().strip('"').strip("'")
        if raw.startswith("/") or raw.startswith("~") or "$" in raw:
            return m.group(0)
        candidate = (file_path.parent / raw).resolve()
        if candidate.exists():
            return f"{m.group('prefix')}{candidate}"
        cand2 = (hypr_root / raw.lstrip("./")).resolve()
        if cand2.exists():
            return f"{m.group('prefix')}{cand2}"
        return m.group(0)

    text = RE_SOURCE_REL.sub(rel_source, text)

    def obsolete(m: re.Match[str]) -> str:
        return f"{m.group('indent')}# NCC-sanitize: obsolete option removed: {m.group('key')}"

    text = OBSOLETE_OPTION.sub(obsolete, text)
    text = RE_TOGGLESPLIT.sub(r"\g<head>layoutmsg, togglesplit\g<tail>", text)
    # fyi (author notify helper) → notify-send
    text = re.sub(r'\bfyi\b', "notify-send", text)
    text = re.sub(
        r'if file_exists\([^\)]*save\.lua[^\)]*\) then\s*\n\s*require\(["\']save["\']\)',
        'if false then\n\t\t-- NCC-sanitize: author save.lua gated off\n\t\trequire("save")',
        text,
    )
    return text


def _iter_text_files(root: Path):
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in TEXT_SUFFIXES and path.name not in (
            "hyprland.conf",
            "hyprland.lua",
        ):
            continue
        yield path


def sanitize_tree(root: Path) -> int:
    changed = 0
    root = root.resolve()

    for lua in root.rglob("hyprland.lua"):
        text = lua.read_text(encoding="utf-8", errors="replace")
        if 'require("save")' in text or "require('save')" in text:
            stub = lua.parent / "save.lua"
            if not stub.is_file():
                stub.write_text(
                    "-- NCC stub: author save plugin not shipped\nreturn {}\n",
                    encoding="utf-8",
                )
                changed += 1

    for path in _iter_text_files(root):
        try:
            original = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        new = _rewrite_text(original, collection_root=root, file_path=path)
        if new != original:
            path.write_text(new, encoding="utf-8")
            changed += 1
    return changed


def _comment_matching_lines(root: Path, needle: str, reason: str) -> int:
    n = 0
    needle_l = needle.lower()
    for path in _iter_text_files(root):
        if path.suffix == ".lua":
            continue
        try:
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines(True)
        except OSError:
            continue
        out = []
        changed = False
        for line in lines:
            stripped = line.lstrip()
            if stripped.startswith("#"):
                out.append(line)
                continue
            if needle_l in line.lower():
                indent = line[: len(line) - len(stripped)]
                out.append(f"{indent}# NCC-sanitize ({reason}): {stripped}")
                changed = True
                n += 1
            else:
                out.append(line)
        if changed:
            path.write_text("".join(out), encoding="utf-8")
    return n


def repair_from_verify_output(root: Path, output: str) -> int:
    clean = RE_ANSI.sub("", output)
    repairs = 0
    for m in RE_OPT_ERR.finditer(clean):
        key = m.group(1).strip()
        repairs += _comment_matching_lines(root, key, f"obsolete {key}")
        if ":" in key:
            repairs += _comment_matching_lines(root, key.split(":")[-1], f"obsolete {key}")
    for m in RE_DISP_ERR.finditer(clean):
        disp = m.group(1).strip()
        repairs += _comment_matching_lines(root, disp, f"bad dispatcher {disp}")
    for m in RE_FIELD_ERR.finditer(clean):
        field = m.group(1).strip()
        repairs += _comment_matching_lines(root, field, f"bad field {field}")
    for m in RE_FIELD_TYPE_ERR.finditer(clean):
        field = m.group(1).strip()
        repairs += _comment_matching_lines(root, field, f"bad field type {field}")
    if RE_DEPRECATED.search(clean):
        repairs += _comment_matching_lines(root, "windowrulev2", "deprecated windowrulev2")
        repairs += _comment_matching_lines(root, "layerrule", "deprecated layerrule")
    if "Stray category close" in clean:
        # comment lines that are only `}` in conf files (risky but needed for ancient configs)
        for path in _iter_text_files(root):
            if path.suffix == ".lua":
                continue
            try:
                lines = path.read_text(encoding="utf-8", errors="replace").splitlines(True)
            except OSError:
                continue
            out = []
            changed = False
            for line in lines:
                if line.strip() == "}":
                    out.append(f"# NCC-sanitize (stray close): {line}")
                    changed = True
                    repairs += 1
                else:
                    out.append(line)
            if changed:
                path.write_text("".join(out), encoding="utf-8")
    return repairs


def verify_and_repair(
    root: Path,
    entry: Path,
    hyprland_bin: str,
    *,
    max_rounds: int = 30,
) -> tuple[bool, str]:
    sanitize_tree(root)
    last = ""
    for _ in range(max_rounds):
        proc = subprocess.run(
            [hyprland_bin, "--verify-config", "-c", str(entry)],
            capture_output=True,
            text=True,
        )
        last = (proc.stdout or "") + (proc.stderr or "")
        if proc.returncode == 0:
            return True, "config ok"
        n = repair_from_verify_output(root, last)
        if n == 0:
            return False, last
    return False, last


def main() -> int:
    p = argparse.ArgumentParser(description="Sanitize hypr rice tree for NCC")
    p.add_argument("root", type=Path)
    p.add_argument("--hyprland", default=None)
    p.add_argument("--entry", default=None)
    args = p.parse_args()
    if not args.root.is_dir():
        print(f"Not a directory: {args.root}", file=sys.stderr)
        return 2
    if args.hyprland and args.entry:
        ok, msg = verify_and_repair(args.root, Path(args.entry), args.hyprland)
        print("ok" if ok else "fail")
        if not ok:
            print(msg[-1000:], file=sys.stderr)
            return 1
        return 0
    n = sanitize_tree(args.root)
    print(f"sanitized_files={n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
