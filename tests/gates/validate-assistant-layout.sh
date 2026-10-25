#!/usr/bin/env bash
# HARD GATE — ncc-assistant tree/staging/entrypoint layout.
# See docs/todo/ncc-assistant-tree-layout-6b2a65d9.plan.md and the module's doc/layout.md.
#
# WHY THIS GATE EXISTS AT ALL
#   No gate in this repo ever BUILDS ncc-assistant's package.nix — everything else only does
#   `nix --parse`/`--eval`. So a layout change (hoist a package, rename an entrypoint, move a
#   catalog) could stay green while every wrapper is broken. This gate closes that hole with
#   checks that are cheap enough to run on every commit.
#
# WHAT IT REMOVES (capability, not a reminder):
#   1. The old tree: `python/`, `ncc_assistant/`, `assistant/` may not exist anywhere in the
#      module. After the hoist there is no second layout to fall back to — a re-introduced
#      `python/ncc_assistant/` would shadow the real packages on PYTHONPATH.
#   2. Importable surface: the module may contain exactly the planned packages, and appRoot
#      must stage exactly that set into its site root. A new top-level package is a new
#      PYTHONPATH name and cannot ride along with a file move.
#   3. Stdlib freedom: no staged name may shadow a stdlib module, and nothing may edit
#      sys.path — that insert is the mechanism which would turn an ordinary submodule file
#      into an importable top-level name again.
#   4. `data/` carries catalogs only, never code, and the planned catalog dirs must exist.
#   5. Loader witnesses: playbooks/eval cases must LOAD and must load from `$MOD/data`.
#      (This is what a silent `return []` degradation would otherwise hide.)
#   6. Entrypoints: every wrapper uses ONE target and the CLI verbs answer `--help`.
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MOD="${NCC_ASSISTANT_MODULE_DIR:-$ROOT/nixos/modules/specialized/ncc-assistant}"
PKG="$MOD/package.nix"
PYTHON="${NCC_ASSISTANT_PYTHON:-python3}"
FAIL=0

# Importable packages of the assistant (Soll-Baum, doc/layout.md). ncc_gui is staged into the
# same site root by package.nix, so it belongs to the collision surface even though the
# gui-engine owns it.
IMPORTABLE=$'cli\ncompanion\ncore\nharness\nplugins\ntray\nwidgets\nwindow'
SITE_SUBPATH="lib/ncc-assistant"
# `$out` top level: the site root plus the three data/doc payloads.
EXPECTED_STAGED=$'AI_KNOWLEDGE.md\ndata\nknowledge\nlib'
EXPECTED_SITE=$'cli\ncompanion\ncore\nharness\nncc_gui\nplugins\ntray\nwidgets\nwindow'
EXPECTED_DATA=$'agents\neval\nmcp\nplaybooks\nprompts'

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-assistant-layout (HARD GATE) ==="

# Session isolation for every Python call below: `paths.config_home()` mkdirs under
# XDG_CONFIG_HOME the moment a package is imported, so an unguarded run would create
# directories in the operator's real ~/.config/ncc-assistant AND read any user playbook
# installed there — making the loader checks depend on the machine instead of the tree.
# HOME deliberately stays real: overriding it drops the user site-packages that provide
# httpx, and the run then dies with ModuleNotFoundError for reasons that look like a code bug.
GATE_XDG="$(mktemp -d)"
trap 'rm -rf "$GATE_XDG"' EXIT
export XDG_CONFIG_HOME="$GATE_XDG"
# The loader witnesses and the entrypoint smoke import from the module itself, so CPython
# would drop __pycache__ into the tree this gate guards — and `ncc system-update --local`
# ships the module directory as it is. Measured: 77 .pyc files after one green run.
export PYTHONDONTWRITEBYTECODE=1

if [[ ! -d "$MOD" ]]; then
  fail "module dir not found: $MOD"
  echo "=== validate-assistant-layout summary ==="
  echo "FAILED"
  exit 1
fi

# ── 1) The old layout stays dead ─────────────────────────────────────────────
# Pre-Phase-2 this gate could only ratchet, because python/ncc_assistant/ still existed. The
# hoist is done, so the ban is absolute: those names must not come back at any depth.
LEGACY=$(find "$MOD" -type d \( -name python -o -name ncc_assistant -o -name assistant \) \
  -not -path '*/node_modules/*' -printf '%P\n' 2>/dev/null | sort || true)
if [[ -n "$LEGACY" ]]; then
  echo "$LEGACY" | sed 's/^/    /'
  fail "legacy import root re-appeared — the hoisted tree is the only layout (doc/layout.md)"
else
  pass "no python/ / ncc_assistant/ / assistant/ left in the module"
fi

# ── 2) The module contains exactly the planned packages ──────────────────────
# A directory with __init__.py at module level is a package. Anything unplanned there is a
# name somebody could import without the plan having accepted it.
PRESENT=$(find "$MOD" -mindepth 2 -maxdepth 2 -name '__init__.py' -printf '%P\n' 2>/dev/null \
  | cut -d/ -f1 | sort -u || true)
if [[ -z "$PRESENT" ]]; then
  fail "no importable package found under $MOD — the module tree is unreadable"
elif [[ "$PRESENT" == "$IMPORTABLE" ]]; then
  pass "module packages are exactly: $(echo "$IMPORTABLE" | tr '\n' ' ')"
else
  diff <(echo "$IMPORTABLE") <(echo "$PRESENT") | sed 's/^/    /' || true
  fail "module-level package set changed — see doc/layout.md before adding a top-level package"
fi

# ── 3) Staging Soll-Menge (appRoot) ─────────────────────────────────────────
# The only collision surface measurable without building: whatever appRoot puts on PYTHONPATH
# becomes an importable name. Two levels matter — the `$out` top level and the site root that
# actually holds the packages.
# `|| true` on every pipeline here is load-bearing: pipefail would abort the gate the moment
# package.nix stops matching the sed range, and an aborted gate reads as "failed for some
# other reason" instead of naming what moved.
STAGED=$(
  sed -n "/appRoot = pkgs.runCommand/,/^  '';/p" "$PKG" \
    | grep -o '\$out/[A-Za-z0-9_.-]*' \
    | sed 's|^\$out/||' \
    | sort -u || true
)
if [[ -z "$STAGED" ]]; then
  fail "could not read appRoot staging targets from $PKG — the staging invariant is unverifiable"
elif [[ "$STAGED" == "$EXPECTED_STAGED" ]]; then
  pass "appRoot stages exactly the Soll-Menge: $(echo "$STAGED" | tr '\n' ' ')"
else
  diff <(echo "$EXPECTED_STAGED") <(echo "$STAGED") | sed 's/^/    /' || true
  fail "appRoot top level changed — each entry is a PYTHONPATH importable name."
fi

# Which names land in the site root. Sources are `${./pkg}` copy items; an explicit
# `$SITE_SUBPATH/<name>` destination counts too (that is how ncc_gui is staged).
# Continuation lines are folded FIRST — the copy spans two lines, and grepping it unfolded
# reads only the tail (`${./harness} ${./plugins}`), which would accuse a correct package.nix
# of dropping the other six packages.
SITE_BLOCK=$(sed -n "/appRoot = pkgs.runCommand/,/^  '';/p" "$PKG" \
  | awk '{ if ($0 ~ /\\$/) { sub(/\\$/, ""); buf = buf $0 " " } else { print buf $0; buf = "" } }' || true)
SOURCES=$(printf '%s\n' "$SITE_BLOCK" \
  | grep "\$out/$SITE_SUBPATH" | grep -v 'mkdir' \
  | grep -o '\${\./[A-Za-z0-9_.-]*}' | sed -e 's|\${\./||' -e 's|}$||' | sort -u || true)
EXPLICIT=$(printf '%s\n' "$SITE_BLOCK" \
  | grep -o "\$out/$SITE_SUBPATH/[A-Za-z0-9_.-]*" | sed "s|.*/||" | grep -v '^$' | sort -u || true)
SITE=$(printf '%s\n%s\n' "$SOURCES" "$EXPLICIT" | grep -v '^$' | sort -u || true)
if [[ -z "$SITE" ]]; then
  fail "could not read the site root ($out/$SITE_SUBPATH) payload from $PKG"
elif [[ "$SITE" == "$EXPECTED_SITE" ]]; then
  pass "site root stages exactly: $(echo "$SITE" | tr '\n' ' ')"
else
  diff <(echo "$EXPECTED_SITE") <(echo "$SITE") | sed 's/^/    /' || true
  fail "site root payload changed — every entry is importable by every NCC GUI"
fi

# ── 4) No importable name shadows the stdlib; nothing edits sys.path ─────────
# The shadow surface is the site root only: PYTHONPATH gets one entry, so a name becomes
# importable exactly when appRoot puts it there. A package submodule does NOT shadow —
# `core/store/paths.py` is `core.store.paths`, while a bare `import secrets` resolves to the
# stdlib (verified against the 3.13 interpreter).
if "$PYTHON" - "$MOD" "$SITE" <<'PY'
import sys
from pathlib import Path

mod, site = Path(sys.argv[1]), sys.argv[2].split()
problems: list[str] = []

shadowed = sorted(n for n in site if n in sys.stdlib_module_names)
if shadowed:
    problems.append(f"shadowing stdlib at importable top level: {' '.join(shadowed)}")

path_hacks = []
for pkg in sorted(n for n in site if n != "ncc_gui"):
    for src in sorted((mod / pkg).rglob("*.py")):
        if "__pycache__" in src.parts:
            continue
        for lineno, line in enumerate(src.read_text(encoding="utf-8").splitlines(), 1):
            if "sys.path" in line and not line.lstrip().startswith("#"):
                path_hacks.append(f"    {src.relative_to(mod)}:{lineno}: {line.strip()}")
problems.extend(path_hacks)
if path_hacks:
    problems.append(
        "    A sys.path insert makes every submodule name importable, which turns a plain"
        "    filename into a stdlib shadow. Paths belong in Settings/env, not in sys.path."
    )

for p in problems:
    print("    " + p)
sys.exit(1 if problems else 0)
PY
then
  pass "importable top level shadows no stdlib module; nothing edits sys.path"
else
  fail "importable name shadows the stdlib, or sys.path was edited (see above)"
fi

# ── 5) data/ carries catalogs only, and carries all of them ─────────────────
if find "$MOD/data" -name '*.py' -print 2>/dev/null | grep -q .; then
  find "$MOD/data" -name '*.py' | sed "s|$MOD/||" | sed 's/^/    /'
  fail "data/ must stay catalog-only (code there gets deployed and imported by accident)"
else
  pass "data/ carries no Python code"
fi

DATA_DIRS=$(find "$MOD/data" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort || true)
if [[ -z "$DATA_DIRS" ]]; then
  fail "data/ is missing or empty — the catalogs have no root"
elif [[ "$DATA_DIRS" == "$EXPECTED_DATA" ]]; then
  pass "data/ holds every catalog: $(echo "$DATA_DIRS" | tr '\n' ' ')"
else
  diff <(echo "$EXPECTED_DATA") <(echo "$DATA_DIRS") | sed 's/^/    /' || true
  fail "data/ catalog set changed (NCC_DATA_ROOT is the loaders' only source)"
fi

# ── 6) Loaders still load, and still load from data/ ─────────────────────────
# Both loaders swallow TypeError/AttributeError and answer [] when their JSON is unreachable.
# A set comparison catches that; a "file exists" check would not. NCC_DATA_ROOT is set here
# exactly as the wrappers set it, so the witness runs the shipped resolution path.
if NCC_DATA_ROOT="$MOD/data" NCC_PROMPTS_ROOT="$MOD/data/prompts" \
   PYTHONPATH="$MOD" "$PYTHON" - "$MOD" <<'PY'
import sys
from pathlib import Path

mod = Path(sys.argv[1]).resolve()
sys.path.insert(0, str(mod))
from core.catalogs.eval_harness import load_eval_cases  # noqa: E402
from core.catalogs.playbooks import list_playbooks  # noqa: E402
from core.store.paths import data_root  # noqa: E402

problems: list[str] = []

if data_root() != mod / "data":
    problems.append(f"data root resolves outside the module: {data_root()}")

pbs = list_playbooks()
if not pbs:
    problems.append("playbooks: loader returned 0 playbooks (silent [] degradation)")
for pb in pbs:
    origin = Path(pb.path or "")
    if pb.source == "builtin" and (mod / "data") not in origin.parents:
        problems.append(f"playbooks: builtin '{pb.name}' loads from outside data/: {origin}")
    if pb.source == "builtin" and not pb.goal.strip():
        problems.append(f"playbooks: builtin '{pb.name}' has no goal to run")

cases = load_eval_cases()
if not cases:
    problems.append("eval: loader returned 0 cases (silent [] degradation)")
for case in cases:
    if not case.tool:
        problems.append(f"eval: case '{case.name}' calls no tool")
    if not case.checks and not case.expected:
        problems.append(f"eval: case '{case.name}' asserts nothing")

for p in problems:
    print("    " + p)
sys.exit(1 if problems else 0)
PY
then
  pass "playbooks + eval cases load, from the module's data/"
else
  fail "catalog loaders degraded (see above) — the tree move broke data resolution"
fi

# ── 6b) Provenance: that data/ IS the loaders' source ───────────────────────
# A green loader check could still be reading an installed copy. Probe on a THROWAWAY data
# root: empty the cases file and remove the playbooks dir there, and both loaders must go
# empty. Never the working tree — the gate must not mutate the checkout it guards.
PROBE="$(mktemp -d)"
trap 'rm -rf "$GATE_XDG" "$PROBE"' EXIT
cp -r "$MOD/data" "$PROBE/data"
printf '[]' > "$PROBE/data/eval/cases.json"
rm -rf "$PROBE/data/playbooks"
if NCC_DATA_ROOT="$PROBE/data" NCC_PROMPTS_ROOT="$PROBE/data/prompts" \
   PYTHONPATH="$MOD" "$PYTHON" - <<'PY'
import sys

from core.catalogs.eval_harness import load_eval_cases  # noqa: E402
from core.catalogs.playbooks import list_playbooks  # noqa: E402

problems = []
if load_eval_cases():
    problems.append("eval: cases survived an emptied cases.json — read from somewhere else")
if list_playbooks():
    problems.append("playbooks: builtins survived a removed playbooks/ dir — read from elsewhere")
for p in problems:
    print("    " + p)
sys.exit(1 if problems else 0)
PY
then
  pass "loader provenance: catalogs resolve to this data/ root, not an installed copy"
else
  fail "catalog loaders have a source outside the tree (see above)"
fi
rm -rf "$PROBE"
trap 'rm -rf "$GATE_XDG"' EXIT

# ── 7) Entrypoints: one target, four verbs answering ──────────────────────────
# Match EVERY `python -m <module>` and require the whole set to be exactly {cli}.
# Grepping for the expected name specifically would silently drop a wrapper renamed to some
# other module — measured: `-m ncc_mcp` matched nothing, leaving one unique target and a green
# run over a broken wrapper.
TARGETS=$(grep -o 'python -m [A-Za-z0-9_.]*' "$PKG" | awk '{print $NF}' | sort -u || true)
if [[ -z "$TARGETS" ]]; then
  fail "no 'python -m' entrypoint found in $PKG — the wrappers are unbound"
elif [[ "$TARGETS" == "cli" ]]; then
  pass "all wrappers bind the one entrypoint: python -m cli"
else
  echo "$TARGETS" | sed 's/^/    /'
  fail "wrappers bind more than one module (or not cli) — every ncc-assistant binary must go through one entrypoint"
fi

# Cheap smoke. Deliberately NOT a Nix build (the gate has to stay fast enough to run on
# every commit) and deliberately NOT HOME-isolated: overriding HOME drops the user
# site-packages that provide httpx and the run dies with ModuleNotFoundError (rc=127/1
# for reasons that look like a code bug). Only XDG_CONFIG_HOME is thrown away and the
# display is unset, which was measured to leave ~/.config/ncc-assistant untouched.
XDG_SMOKE="$(mktemp -d)"
SMOKE_FAILED=0
for verb in "--help" "mcp --help" "tray --help" "companion --help"; do
  # shellcheck disable=SC2086  # verb is intentionally word-split into argv
  if ! out=$(timeout 30 env -u DISPLAY -u WAYLAND_DISPLAY \
      XDG_CONFIG_HOME="$XDG_SMOKE" \
      NCC_DATA_ROOT="$MOD/data" NCC_PROMPTS_ROOT="$MOD/data/prompts" \
      PYTHONPATH="$MOD" \
      "$PYTHON" -m cli $verb 2>&1); then
    echo "$out" | tail -5 | sed 's/^/    /'
    fail "entrypoint smoke: 'ncc ai $verb' exited non-zero"
    SMOKE_FAILED=1
  elif ! printf '%s' "$out" | grep -qi 'usage:'; then
    fail "entrypoint smoke: 'ncc ai $verb' answered without usage text"
    SMOKE_FAILED=1
  fi
done
rm -rf "$XDG_SMOKE"
if [[ "$SMOKE_FAILED" -eq 0 ]]; then
  pass "entrypoint smoke: ncc ai {--help, mcp, tray, companion} all answer"
fi

echo ""
echo "=== validate-assistant-layout summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — assistant layout/staging/entrypoint invariant broken."
  echo "Plan: docs/todo/ncc-assistant-tree-layout-6b2a65d9.plan.md"
  exit 1
fi
echo "OK — hoisted tree + staging Soll-Menge + stdlib freedom + data/-only-catalogs + loader witnesses + entrypoints green."
exit 0
