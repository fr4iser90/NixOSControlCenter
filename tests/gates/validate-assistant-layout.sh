#!/usr/bin/env bash
# HARD GATE — ncc-assistant tree/staging/entrypoint layout.
# See docs/todo/ncc-assistant-tree-layout-6b2a65d9.plan.md (Schritt 0).
#
# WHY THIS GATE EXISTS AT ALL
#   No gate in this repo ever BUILDS ncc-assistant's package.nix — everything else only does
#   `nix --parse`/`--eval`. So a layout change (hoist a package, rename an entrypoint, move a
#   catalog out of the importable package) could stay green while every wrapper is broken.
#   This gate closes exactly that hole with the cheap, green-today part of the invariant.
#
# WHAT IT REMOVES (capability, not a reminder):
#   1. Staging Soll-Menge: `$out` must contain exactly {AI_KNOWLEDGE.md, knowledge,
#      ncc_assistant, ncc_gui, prompts}. A new top-level entry is a new name on PYTHONPATH —
#      unplanned hoists are rejected, they cannot ride along with a file move.
#   2. Stdlib freedom: no importable name may shadow a stdlib module.
#   3. No code in `data/`: catalog root stays data-only, so it can never grow into a package.
#   4. Loader witnesses: playbooks/eval cases must still LOAD, and must still load FROM the
#      package — proven by running the loaders and reading back where the files came from.
#      (This is what a silent `return []` degradation would otherwise hide.)
#   5. Entrypoints: all 5 wrappers use ONE target, and all 4 CLI verbs answer `--help`.
#   6. Ratchet: no new top-level `.py` in python/ncc_assistant/ beyond the recorded count.
#
# The absolute ban on `python/ncc_assistant/` (Phase 2 end state) is deliberately NOT here —
# pre-commit runs this whole net, so a check that is red today would block every commit
# between here and Phase 2. It lands with the split, not before it.
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MOD="${NCC_ASSISTANT_MODULE_DIR:-$ROOT/nixos/modules/specialized/ncc-assistant}"
PKG="$MOD/package.nix"
PYROOT="$MOD/python"
PYTHON="${NCC_ASSISTANT_PYTHON:-python3}"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-assistant-layout (HARD GATE) ==="

# Session isolation for every Python call below: `paths.config_home()` mkdirs under
# XDG_CONFIG_HOME the moment the package is imported, so an unguarded run would create
# directories in the operator's real ~/.config/ncc-assistant AND read any user playbook
# installed there — making the loader checks depend on the machine instead of the tree.
# HOME deliberately stays real: overriding it drops the user site-packages that provide
# httpx, and the run then dies with ModuleNotFoundError for reasons that look like a code bug.
GATE_XDG="$(mktemp -d)"
PROBE=""
# The last command in the trap must not fail: under set -e a false `[[ ]]` here would turn a
# clean gate run red on the way out.
trap 'rm -rf "$GATE_XDG"; [[ -z "$PROBE" ]] || rm -rf "$PROBE"' EXIT
export XDG_CONFIG_HOME="$GATE_XDG"

if [[ ! -d "$MOD" ]]; then
  fail "module dir not found: $MOD"
  echo "=== validate-assistant-layout summary ==="
  echo "FAILED"
  exit 1
fi

# ── 1) Staging Soll-Menge (appRoot top level) ────────────────────────────────
# The only collision surface we can measure without building: whatever appRoot puts at the
# top of $out becomes an importable name on PYTHONPATH. ncc_gui ships as a submodule there
# (staged AS ncc_gui), which is why hoisting a second `widgets/` next to it is not a hard
# collision — but an unplanned top-level name is.
EXPECTED_STAGED=$'AI_KNOWLEDGE.md\nknowledge\nncc_assistant\nncc_gui\nprompts'
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
  echo "    If this is the planned Phase-2 layout, update EXPECTED_STAGED HERE and in"
  echo "    docs/todo/ncc-assistant-tree-layout-6b2a65d9.plan.md together."
fi

# ── 2) No importable name shadows the stdlib ─────────────────────────────────
# The shadow surface is the STAGING ROOT only: `$out` is the single PYTHONPATH entry, so a
# name becomes importable exactly when appRoot puts it there. A package submodule does NOT
# shadow — `ncc_assistant/secrets.py` is `ncc_assistant.secrets`, while a bare
# `import secrets` resolves to the stdlib (verified against the 3.13 interpreter). Checking
# file basenames instead would flag 0 real risks and hide the real one.
#
# The mechanism that WOULD make a submodule name importable is a sys.path insert; the tree
# does that zero times today, so that ban is green now and is what keeps this check true
# after Phase 2 scatters names like `copy/`, `types/`, `queue/` around the tree.
if "$PYTHON" - "$PYROOT" "$STAGED" <<'PY'
import sys
from pathlib import Path

pyroot, staged = Path(sys.argv[1]), sys.argv[2].split()
names = set(staged)
if pyroot.is_dir():
    names |= {p.stem if p.suffix == ".py" else p.name for p in pyroot.iterdir()}
shadowed = sorted(n for n in names if n in sys.stdlib_module_names)
if shadowed:
    print(f"    shadowing stdlib at importable top level: {' '.join(shadowed)}")

path_hacks = []
for src in sorted((pyroot / "ncc_assistant").rglob("*.py")):
    if "__pycache__" in src.parts:
        continue
    for lineno, line in enumerate(src.read_text(encoding="utf-8").splitlines(), 1):
        if "sys.path" in line and not line.lstrip().startswith("#"):
            path_hacks.append(f"    {src.relative_to(pyroot)}:{lineno}: {line.strip()}")
for line in path_hacks:
    print(line)
if path_hacks:
    print("    A sys.path insert makes every submodule name importable, which turns a plain")
    print("    filename into a stdlib shadow. Paths belong in Settings/env, not in sys.path.")
sys.exit(1 if (shadowed or path_hacks) else 0)
PY
then
  pass "importable top level shadows no stdlib module; nothing edits sys.path"
else
  fail "importable name shadows the stdlib, or sys.path was edited (see above)"
fi

# ── 3) data/ carries catalogs only, never code ───────────────────────────────
if find "$MOD/data" -name '*.py' -print 2>/dev/null | grep -q .; then
  find "$MOD/data" -name '*.py' | sed "s|$MOD/||" | sed 's/^/    /'
  fail "data/ must stay catalog-only (code there gets deployed and imported by accident)"
else
  pass "data/ carries no Python code"
fi

# ── 4) Loaders still load, and still load from the package ───────────────────
# Both loaders swallow TypeError/AttributeError and answer [] when their JSON leaves the
# importable package. A set comparison catches that; a "file exists" check would not.
if "$PYTHON" - "$PYROOT" <<'PY'
import sys
from pathlib import Path

sys.path.insert(0, str(Path(sys.argv[1]).resolve()))
from ncc_assistant.eval_harness import load_eval_cases  # noqa: E402
from ncc_assistant.playbooks import list_playbooks  # noqa: E402

pkg = Path(sys.argv[1]).resolve() / "ncc_assistant"
problems: list[str] = []

pbs = list_playbooks()
if not pbs:
    problems.append("playbooks: loader returned 0 playbooks (silent [] degradation)")
for pb in pbs:
    origin = Path(pb.path or "")
    if pb.source == "builtin" and pkg not in origin.parents:
        problems.append(f"playbooks: builtin '{pb.name}' loads from outside the package: {origin}")
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

# Provenance: an empty packaged cases.json must take the count to 0. Without this the check
# would pass on a stale copy and the loader could be reading anywhere.
cases_file = pkg / "eval" / "cases.json"
backup = cases_file.with_name("cases.json.layout-gate-bak")
before = len(cases)
try:
    backup.write_bytes(cases_file.read_bytes())
    cases_file.write_text("[]", encoding="utf-8")
    if len(load_eval_cases()) != 0:
        problems.append("eval: packaged cases.json is not the loader's source (read elsewhere)")
finally:
    backup.replace(cases_file)
if len(load_eval_cases()) != before:
    problems.append(f"eval: packaged catalog not restored ({before} -> {len(load_eval_cases())})")

for p in problems:
    print("    " + p)
sys.exit(1 if problems else 0)
PY
then
  pass "playbooks + eval cases load, from inside the package"
else
  fail "catalog loaders degraded (see above) — the tree move broke data resolution"
fi

# ── 4b) Provenance: the package copy IS the loaders' source ──────────────────
# A green loader check on the repo tree could still be reading from an installed/stale
# ncc_assistant. Probe on a THROWAWAY COPY — never the working tree, or the gate would
# mutate the checkout it is guarding (and race a concurrent pre-commit run).
PROBE="$(mktemp -d)"
cp -r "$PYROOT/ncc_assistant" "$PROBE/ncc_assistant"
rm -rf "$PROBE/ncc_assistant/__pycache__" "$PROBE/ncc_assistant/playbooks"
# mkdir first: with eval/ gone, the redirect below would abort the whole gate on a shell
# error instead of reporting the real cause a few lines later.
mkdir -p "$PROBE/ncc_assistant/eval"
printf '[]' > "$PROBE/ncc_assistant/eval/cases.json"
if (cd "$PROBE" && "$PYTHON" - "$PROBE" <<'PY'
import sys
from pathlib import Path

# cwd == probe dir and nothing else on the path, so an import that escapes the copy proves
# the loader has a source outside the tree.
sys.path.insert(0, str(Path(sys.argv[1]).resolve()))
from ncc_assistant.eval_harness import load_eval_cases  # noqa: E402
from ncc_assistant.playbooks import list_playbooks  # noqa: E402

problems = []
if load_eval_cases():
    problems.append("eval: cases survived an emptied packaged cases.json — read from somewhere else")
if list_playbooks():
    problems.append("playbooks: builtins survived a removed playbooks/ dir — read from somewhere else")
for p in problems:
    print("    " + p)
sys.exit(1 if problems else 0)
PY
); then
  pass "loader provenance: catalogs resolve to this tree, not an installed copy"
else
  fail "catalog loaders have a source outside the tree (see above)"
fi
rm -rf "$PROBE"
PROBE=""

# ── 5) Entrypoints: one target, four verbs answering ──────────────────────────
# Match EVERY `python -m <module>` and require the whole set to be exactly {ncc_assistant}.
# Grepping for `ncc_assistant…` specifically would silently drop a wrapper renamed to some
# other module — measured: `-m ncc_mcp` matched nothing, leaving one unique target and a green
# run over a broken wrapper.
TARGETS=$(grep -o 'python -m [A-Za-z0-9_.]*' "$PKG" | awk '{print $NF}' | sort -u || true)
if [[ -z "$TARGETS" ]]; then
  fail "no 'python -m' entrypoint found in $PKG — the wrappers are unbound"
elif [[ "$TARGETS" == "ncc_assistant" ]]; then
  pass "all 5 wrappers bind the one entrypoint: python -m ncc_assistant"
else
  echo "$TARGETS" | sed 's/^/    /'
  fail "wrappers bind more than one module (or not ncc_assistant) — every ncc-assistant binary must go through one entrypoint"
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
      PYTHONPATH="$PYROOT" \
      "$PYTHON" -m ncc_assistant $verb 2>&1); then
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

# ── 6) Ratchet: the flat pile may not grow ───────────────────────────────────
# Phase 2 splits python/ncc_assistant/*.py into domain packages. Until then, no new module
# may land at package top level — new code belongs in a package, not in the flat pile.
FLAT_CEILING=69
FLAT=$(find "$PYROOT/ncc_assistant" -maxdepth 1 -name '*.py' | wc -l)
if [[ "$FLAT" -le "$FLAT_CEILING" ]]; then
  pass "package top level holds $FLAT modules (ceiling $FLAT_CEILING — it may shrink, not grow)"
else
  find "$PYROOT/ncc_assistant" -maxdepth 1 -name '*.py' -printf '%f\n' | sort | sed 's/^/    /'
  fail "package top level grew to $FLAT modules (ceiling $FLAT_CEILING) — new code goes into a package"
fi

echo ""
echo "=== validate-assistant-layout summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — assistant layout/staging/entrypoint invariant broken."
  echo "Plan: docs/todo/ncc-assistant-tree-layout-6b2a65d9.plan.md"
  exit 1
fi
echo "OK — staging Soll-Menge + stdlib freedom + data/-only-catalogs + loader witnesses + entrypoints + ratchet green."
exit 0
