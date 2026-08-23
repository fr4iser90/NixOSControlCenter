#!/usr/bin/env bash
# HARD GATE — auto-detect missing module version bumps / migrations.
#
# When nixos/ files are deleted (git), the owning module MUST list them in
# <module>/migrations/vFROM-to-vTO.nix (removeRelativePaths) and bump version to `to`.
# Additive edits do NOT require a bump.
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NIXOS="$ROOT/nixos"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-module-migrations (HARD GATE) ==="

REPORT=$(mktemp)
set +e
python3 - "$ROOT" "$NIXOS" "$REPORT" <<'PY'
import json, os, re, subprocess, sys
from pathlib import Path

root = Path(sys.argv[1])
nixos = Path(sys.argv[2])
report_path = Path(sys.argv[3])
issues: list[str] = []
notes: list[str] = []

MIG_NAME = re.compile(r"^v([0-9]+(?:\.[0-9]+)*)-to-v([0-9]+(?:\.[0-9]+)*)\.nix$")
SKIP_SUFFIX = (".md", ".mdc", ".json", ".lock", ".png", ".svg", ".jpg", ".gif", ".gitignore", ".gitkeep")
SKIP_PART = ("/doc/", "/docs/", "/ai/", "/.cursor/")


def parse_ver(v: str):
    out = []
    for p in v.split("."):
        try:
            out.append(int(p))
        except ValueError:
            out.append(0)
    return tuple(out)


def ver_ge(a: str, b: str) -> bool:
    return parse_ver(a) >= parse_ver(b)


def git_out(args: list[str]) -> list[str]:
    try:
        text = subprocess.check_output(
            args, cwd=str(root), stderr=subprocess.DEVNULL, text=True
        )
        return [ln.strip() for ln in text.splitlines() if ln.strip()]
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []


def deleted_nixos_paths() -> set[str]:
    if not (root / ".git").exists() and not (root / ".git").is_file():
        notes.append("no .git — skip deletion detect (consistency only)")
        return set()
    deleted: set[str] = set()
    base = None
    for ref in ("origin/main", "origin/master", "main", "master"):
        mb = git_out(["git", "merge-base", "HEAD", ref])
        if mb:
            base = mb[0]
            notes.append(f"deletion base: {ref} ({base[:12]})")
            break
    if base:
        deleted.update(git_out(["git", "diff", "--diff-filter=D", "--name-only", f"{base}...HEAD"]))
    else:
        notes.append("no main/master merge-base — using HEAD~30 + working tree")
        deleted.update(git_out(["git", "diff", "--diff-filter=D", "--name-only", "HEAD~30...HEAD"]))
    deleted.update(git_out(["git", "diff", "--diff-filter=D", "--name-only", "HEAD"]))
    deleted.update(git_out(["git", "diff", "--cached", "--diff-filter=D", "--name-only"]))

    keep = set()
    for p in deleted:
        if not p.startswith("nixos/"):
            continue
        if any(p.endswith(s) for s in SKIP_SUFFIX):
            continue
        if any(s in p for s in SKIP_PART):
            continue
        # code / script trees matter; ignore pure noise
        if not (
            p.endswith(".nix")
            or p.endswith(".sh")
            or "/scripts/" in p
            or "/ui/" in p
            or "/handlers/" in p
            or "/components/" in p
        ):
            continue
        keep.add(p)
    return keep


def module_roots() -> list[Path]:
    roots = []
    for default in nixos.rglob("default.nix"):
        # skip nested package/default.nix noise: require sibling options.nix OR migrations/ OR _module.metadata
        text = default.read_text(encoding="utf-8", errors="replace")
        if "_module.metadata" not in text and "version =" not in text:
            continue
        # ignore deep template defaults
        if "/templates/" in str(default) or "/host-blueprints/" in str(default):
            continue
        if "/migrations/" in str(default):
            continue
        roots.append(default.parent)
    return roots


def module_version(mod: Path) -> str | None:
    default = mod / "default.nix"
    options = mod / "options.nix"
    if default.is_file():
        t = default.read_text(encoding="utf-8", errors="replace")
        m = re.search(
            r'_module\.metadata\s*=\s*\{[^}]*?\bversion\s*=\s*"([^"]+)"',
            t,
            re.S,
        )
        if m:
            return m.group(1)
    if options.is_file():
        t = options.read_text(encoding="utf-8", errors="replace")
        m = re.search(
            r'_version\s*=\s*lib\.mkOption\s*\{.*?default\s*=\s*"([^"]+)"',
            t,
            re.S,
        )
        if m:
            return m.group(1)
    return None


def load_migration(mig: Path) -> dict:
    # Prefer nix eval; regex fallback if nixpkgs unavailable in env
    expr = (
        "let lib = (import <nixpkgs> {}).lib; "
        f"m = import {mig} {{ inherit lib; }}; in "
        "{{ id = m.id or \"\"; from = m.from or \"\"; to = m.to or \"\"; "
        "paths = m.removeRelativePaths or []; }}"
    )
    try:
        out = subprocess.check_output(
            ["nix-instantiate", "--eval", "--strict", "--json", "-E", expr],
            stderr=subprocess.DEVNULL,
            text=True,
        )
        return json.loads(out)
    except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError):
        text = mig.read_text(encoding="utf-8", errors="replace")
        fm = MIG_NAME.match(mig.name)
        block = re.search(r"removeRelativePaths\s*=\s*\[(.*?)\];", text, re.S)
        paths = re.findall(r'"([^"]+)"', block.group(1)) if block else []
        from_m = re.search(r'\bfrom\s*=\s*"([^"]+)"', text)
        to_m = re.search(r'\bto\s*=\s*"([^"]+)"', text)
        return {
            "id": "",
            "from": (from_m.group(1) if from_m else (fm.group(1) if fm else "")),
            "to": (to_m.group(1) if to_m else (fm.group(2) if fm else "")),
            "paths": paths,
        }


def path_covered(rel: str, paths: list[str]) -> bool:
    rel = rel.rstrip("/")
    for p in paths:
        p = p.rstrip("/")
        if not p:
            continue
        if rel == p or rel.startswith(p + "/") or p.startswith(rel + "/"):
            return True
    return False


def owning_module(repo_rel: str, roots: list[Path]) -> Path | None:
    """Longest module root prefix under nixos/ for a deleted repo-relative path."""
    try:
        under = Path(repo_rel).relative_to("nixos")
    except ValueError:
        return None
    best = None
    best_len = -1
    for mod in roots:
        try:
            rel = under.relative_to(mod.relative_to(nixos))
        except ValueError:
            continue
        # must be strictly inside module (or equal — deleted default.nix rare)
        n = len(mod.parts)
        if n > best_len:
            best = mod
            best_len = n
    return best


# ── 1) Migration file consistency ───────────────────────────────────────────
roots = module_roots()
for mig in sorted(nixos.glob("**/migrations/v*-to-v*.nix")):
    if "config-migration" in str(mig) or "config-schema" in str(mig):
        continue
    fm = MIG_NAME.match(mig.name)
    if not fm:
        issues.append(f"{mig.relative_to(root)}: name must be vFROM-to-vTO.nix")
        continue
    file_from, file_to = fm.group(1), fm.group(2)
    data = load_migration(mig)
    if data.get("from") and data["from"] != file_from:
        issues.append(
            f"{mig.relative_to(root)}: from={data['from']!r} != filename {file_from!r}"
        )
    if data.get("to") and data["to"] != file_to:
        issues.append(
            f"{mig.relative_to(root)}: to={data['to']!r} != filename {file_to!r}"
        )
    mod = mig.parent.parent
    ver = module_version(mod)
    if ver and data.get("to") and not ver_ge(ver, data["to"]):
        issues.append(
            f"{mod.relative_to(nixos)}: version {ver!r} < migration to={data['to']!r} "
            f"— bump _module.metadata.version / options _version"
        )

# ── 2) Git deletions that need migrations (packaging / leftover orphans) ─────
# rsync --delete covers normal module code. Migrations are required when a leftover
# file would still be *evaluated* (install-wizard scripts walk, similar packagers).
deleted = deleted_nixos_paths()
SENSITIVE = ("/scripts/", "/ui/prompts/", "/ui/gui/")
for repo_rel in sorted(deleted):
    if not any(s in f"/{repo_rel}" or s in repo_rel for s in SENSITIVE):
        # also allow prefix without leading nuance
        if not any(x in repo_rel for x in ("/scripts/", "/ui/prompts/", "/ui/gui/")):
            continue
    mod = owning_module(repo_rel, roots)
    if mod is None:
        continue
    try:
        rel_mod = str(Path(repo_rel).relative_to(Path("nixos") / mod.relative_to(nixos)))
    except ValueError:
        continue
    if rel_mod.startswith("migrations/"):
        continue
    paths: list[str] = []
    mig_dir = mod / "migrations"
    if mig_dir.is_dir():
        for mig in mig_dir.glob("v*-to-v*.nix"):
            paths.extend(load_migration(mig).get("paths") or [])
    if not path_covered(rel_mod, paths):
        issues.append(
            f"deleted {repo_rel} needs migration — add "
            f"{mod.relative_to(nixos)}/migrations/vFROM-to-vTO.nix "
            f"with removeRelativePaths = [ \"{rel_mod}\" ]; and bump module version"
        )

# ── 3) Packaging orphan guards (missing isDataNix paths) need migrations ────
for scripts_default in nixos.glob("**/scripts/default.nix"):
    mod = scripts_default.parent.parent
    if not (mod / "default.nix").is_file():
        continue
    text = scripts_default.read_text(encoding="utf-8", errors="replace")
    for m in re.finditer(r'rel\s*==\s*"([^"]+\.nix)"', text):
        rel = m.group(1)
        if (scripts_default.parent / rel).exists():
            continue
        paths = []
        mig_dir = mod / "migrations"
        if mig_dir.is_dir():
            for mig in mig_dir.glob("v*-to-v*.nix"):
                paths.extend(load_migration(mig).get("paths") or [])
        candidates = [rel, f"scripts/{rel}"]
        if not any(path_covered(c, paths) for c in candidates):
            issues.append(
                f"{scripts_default.relative_to(root)}: isDataNix lists missing {rel!r} "
                f"without migration coverage — add removeRelativePaths "
                f"(e.g. \"scripts/{rel}\") under {mod.relative_to(nixos)}/migrations/"
            )

lines = []
if notes:
    lines.append("NOTES:")
    lines.extend(f"  - {n}" for n in notes)
if issues:
    lines.append("ISSUES:")
    lines.extend(f"  - {i}" for i in issues)
else:
    lines.append("OK: no missing migrations / version mismatches detected")
report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
sys.exit(1 if issues else 0)
PY
RC=$?
set -e

if [[ -s "$REPORT" ]]; then
  sed 's/^/  /' "$REPORT"
fi
rm -f "$REPORT"

if [[ "$RC" -ne 0 ]]; then
  fail "auto-detect: missing migrations and/or version bumps (see ISSUES)"
else
  pass "auto-detect: deletions covered; migration↔version consistent"
fi

echo "=== module-migrations summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — see .cursor/rules/ncc-module-migrations.mdc"
  exit 1
fi
echo "OK — migration auto-detect gate green."
exit 0
