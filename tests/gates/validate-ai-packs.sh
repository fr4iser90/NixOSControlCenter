#!/usr/bin/env bash
# HARD GATE — domain AI packs match ncc-assistant discovery contract.
#
# SSOT: nixos/modules/specialized/ncc-assistant/doc/domain-ai-packs.md
#
# Rules:
#   - If ai/ exists → ai/manifest.nix required
#   - manifest.nix must set domain + description (attrset)
#   - ai/tools/*.json must have name, description, inputSchema, argv, risk, permission
#   - risk ∈ {read, write, rebuild}; argv = list of strings
#   - tool name domain.<d>.* must use the pack's domain
#   - ai/{skills,domains,context}/*.json must parse as JSON objects
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NIXOS="$ROOT/nixos"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-ai-packs (HARD GATE) ==="

if python3 - "$NIXOS" <<'PY'
import json
import re
import sys
from pathlib import Path

nixos = Path(sys.argv[1])
errors: list[str] = []
packs = 0
tools = 0

REQUIRED_TOOL = ("name", "description", "inputSchema", "argv", "risk", "permission")
RISKS = frozenset({"read", "write", "rebuild"})
EXTRA_JSON_DIRS = ("skills", "domains", "context")

domain_re = re.compile(r'^\s*domain\s*=\s*"([^"]+)"\s*;', re.M)
desc_re = re.compile(r'^\s*description\s*=\s*"([^"]*)"\s*;', re.M)


def parse_manifest(path: Path):
    text = path.read_text(encoding="utf-8", errors="replace")
    dm = domain_re.search(text)
    ds = desc_re.search(text)
    return (dm.group(1) if dm else None, ds.group(1) if ds else None)


for ai_dir in sorted(nixos.rglob("ai")):
    if not ai_dir.is_dir():
        continue
    parent = ai_dir.parent
    if not (parent / "options.nix").is_file() or not (parent / "default.nix").is_file():
        continue

    rel_mod = parent.relative_to(nixos)
    man = ai_dir / "manifest.nix"
    if not man.is_file():
        errors.append(f"{rel_mod}: ai/ present without ai/manifest.nix")
        continue

    packs += 1
    domain, description = parse_manifest(man)
    if not domain:
        errors.append(f"{rel_mod}: ai/manifest.nix missing domain = \"…\";")
    if description is None:
        errors.append(f"{rel_mod}: ai/manifest.nix missing description = \"…\";")

    tools_dir = ai_dir / "tools"
    if tools_dir.is_dir():
        for jf in sorted(tools_dir.glob("*.json")):
            tools += 1
            rel = jf.relative_to(nixos)
            try:
                data = json.loads(jf.read_text(encoding="utf-8"))
            except json.JSONDecodeError as e:
                errors.append(f"{rel}: invalid JSON ({e})")
                continue
            if not isinstance(data, dict):
                errors.append(f"{rel}: tool must be a JSON object")
                continue
            missing = [k for k in REQUIRED_TOOL if k not in data]
            if missing:
                errors.append(f"{rel}: missing fields {missing}")
                continue
            if data["risk"] not in RISKS:
                errors.append(f"{rel}: risk must be one of {sorted(RISKS)} (got {data['risk']!r})")
            if not isinstance(data["argv"], list) or not all(isinstance(x, str) for x in data["argv"]):
                errors.append(f"{rel}: argv must be a list of strings")
            if not isinstance(data["inputSchema"], dict):
                errors.append(f"{rel}: inputSchema must be an object")
            name = data["name"]
            if not isinstance(name, str) or not name:
                errors.append(f"{rel}: name must be a non-empty string")
            elif name.startswith("domain.") and domain:
                parts = name.split(".")
                if len(parts) < 3 or parts[0] != "domain" or parts[1] != domain:
                    errors.append(
                        f"{rel}: name {name!r} must be domain.{domain}.<verb> "
                        f"(or bare verb for discovery prefix)"
                    )

    for sub in EXTRA_JSON_DIRS:
        d = ai_dir / sub
        if not d.is_dir():
            continue
        for jf in sorted(d.glob("*.json")):
            rel = jf.relative_to(nixos)
            try:
                data = json.loads(jf.read_text(encoding="utf-8"))
            except json.JSONDecodeError as e:
                errors.append(f"{rel}: invalid JSON ({e})")
                continue
            if not isinstance(data, dict):
                errors.append(f"{rel}: must be a JSON object")

if errors:
    print("ISSUES:")
    for e in errors:
        print(f"  - {e}")
    print(f"packs={packs} tools={tools} issues={len(errors)}")
    sys.exit(1)

print(f"OK: {packs} AI packs, {tools} tools — manifest + tool contract green")
sys.exit(0)
PY
then
  pass "AI pack manifests + tools"
else
  fail "AI pack contract broken"
fi

if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — AI packs not uniform."
  exit 1
fi
echo "OK — AI packs green."
exit 0
