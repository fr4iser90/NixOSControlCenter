#!/usr/bin/env bash
# Catch bash ${VAR} / ${VAR:-} in Nix '' strings (classic nix-build footgun).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIXOS="$ROOT/nixos"

FAIL=0

python3 - "$NIXOS" <<'PY' || FAIL=1
import re, sys, os
root = sys.argv[1]

VAR = r"[A-Za-z_][A-Za-z0-9_]*"
PLACE = "\0ESC\0"

bash_op = re.compile(
    r"\$\{"
    r"(?:"
    r"[A-Za-z_][A-Za-z0-9_]*:[-+=?]|"
    r"#|"
    r"![A-Za-z_]|"
    r"selected_[A-Za-z0-9_]+|"
    r"NCC_[A-Za-z0-9_]+|"
    r"TMPDIR:[-+=?]"
    r")"
)
bash_suffix = re.compile(rf"=\s*\"\$\{{({VAR})\}}(?=[A-Za-z0-9_])")
bash_bare_ref = re.compile(rf"\$\{{({VAR})(?:\}}|\[)")

WRITE = re.compile(
    r"pkgs\.(?:writeText|writeScriptBin|writeShellScript|writeShellScriptBin)\b"
)


def skip_dq(text: str, i: int) -> int:
    """i at opening \"; return index after closing \"."""
    i += 1
    while i < len(text):
        if text[i] == "\\":
            i += 2
            continue
        if text[i] == '"':
            return i + 1
        i += 1
    return i


def skip_sq_string(text: str, i: int) -> int:
    """i at opening ''; return index after closing '' (Nix escapes ''${ ''' )."""
    i += 2
    while i < len(text) - 1:
        if text[i : i + 2] == "${":
            i = skip_antiquote(text, i)
            continue
        if text[i : i + 2] == "''":
            nxt = text[i + 2] if i + 2 < len(text) else ""
            if nxt in ("$", "'"):
                i += 2
                continue
            return i + 2
        i += 1
    return i


def skip_antiquote(text: str, i: int) -> int:
    """i at '${'; skip balanced Nix antiquotation (strings + braces)."""
    i += 2
    depth = 1
    while i < len(text) and depth > 0:
        if text[i : i + 2] == "''":
            i = skip_sq_string(text, i)
            continue
        if text[i] == '"':
            i = skip_dq(text, i)
            continue
        if text[i : i + 2] == "${":
            depth += 1
            i += 2
            continue
        if text[i] == "{":
            depth += 1
            i += 1
            continue
        if text[i] == "}":
            depth -= 1
            i += 1
            continue
        i += 1
    return i


def extract_nix_sq_bodies(text: str) -> list[str]:
    """Bodies of ''…'' after pkgs.write* — skip nested '' inside ${…}."""
    bodies = []
    for m in WRITE.finditer(text):
        i = m.end()
        while i < len(text) - 1:
            if text[i : i + 2] == "''":
                i += 2
                start = i
                while i < len(text) - 1:
                    if text[i : i + 2] == "${":
                        i = skip_antiquote(text, i)
                        continue
                    if text[i : i + 2] == "''":
                        nxt = text[i + 2] if i + 2 < len(text) else ""
                        if nxt in ("$", "'"):
                            i += 2
                            continue
                        bodies.append(text[start:i])
                        break
                    i += 1
                break
            i += 1
    return bodies


def bash_bound_names(body: str) -> set[str]:
    names: set[str] = set()
    skip = {"local", "read", "for", "in", "do", "done", "IFS"}
    for m in re.finditer(r"\blocal\s+((?:-[a-zA-Z]\s+)*)([^\n;#]+)", body):
        before_eq = m.group(2).split("=", 1)[0]
        for tok in re.findall(rf"\b({VAR})\b", before_eq):
            if tok not in skip:
                names.add(tok)
    for m in re.finditer(r"\bread\s+((?:-[a-zA-Z]\s+)*)([^\n;#]+)", body):
        for tok in re.findall(rf"\b({VAR})\b", m.group(2)):
            if tok not in skip:
                names.add(tok)
    for m in re.finditer(rf"\bfor\s+({VAR})\s+in\b", body):
        names.add(m.group(1))
    return names


def check_line(path, i, line, issues, bound: set[str]):
    # ui.badges.success "…''${VAR}" — Nix evals the string arg (footgun); use $VAR
    if re.search(r'(?:badges|messages)\.\w+\s+"[^"]*\'\'\$\{', line):
        issues.append(
            (
                path,
                i,
                line.strip()[:100],
                "ui.badges/messages: use $VAR not ''${VAR} in Nix string arg",
            )
        )
        return
    scrubbed = line.replace("''${", PLACE)
    scrubbed = re.sub(r"\\\$\{", PLACE, scrubbed)
    if bash_op.search(scrubbed):
        issues.append((path, i, line.strip()[:100], "bash ${var:-/+/:=} / ${#…}"))
        return
    if bash_suffix.search(scrubbed):
        issues.append((path, i, line.strip()[:100], "bash ${var} glued suffix — use ''${var}"))
        return
    for m in bash_bare_ref.finditer(scrubbed):
        name = m.group(1)
        if name not in bound:
            continue
        if re.search(rf'(?:^|[;\s]){name}="\$\{{{name}\}}"', scrubbed):
            continue
        issues.append(
            (
                path,
                i,
                line.strip()[:100],
                f"bash ${{{name}}} (local/read/for) — use ''${{{name}}} or ${name}",
            )
        )
        return


issues = []
for dirpath, _, files in os.walk(root):
    for name in files:
        if not name.endswith(".nix"):
            continue
        path = os.path.join(dirpath, name)
        text = open(path, encoding="utf-8", errors="replace").read()
        if "builtins.fromJSON" in text and "writeText" in text and "pkgs.writeText" in text:
            if text.count("pkgs.writeText") == text.count("builtins.fromJSON"):
                continue
        for body in extract_nix_sq_bodies(text):
            bound = bash_bound_names(body)
            for i, line in enumerate(body.splitlines(), 1):
                check_line(path, i, line, issues, bound)

if issues:
    print("FAIL: bash-style ${ in Nix '' strings (use ''${ for shell, or $var in ui.messages):")
    for path, ln, content, hint in issues[:40]:
        print(f"  {path}:{ln}: [{hint}] {content}")
    if len(issues) > 40:
        print(f"  … and {len(issues) - 40} more")
    sys.exit(1)
print(f"OK: checked inline '' bash blocks ({len(issues)} issues)")
PY

if [[ "$FAIL" -ne 0 ]]; then exit 1; fi
