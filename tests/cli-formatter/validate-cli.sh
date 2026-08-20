#!/usr/bin/env bash
# Automated CLI / cli-formatter static + smoke checks.
# Does NOT run live `ncc` against /etc/nixos (see MANUAL.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0
warn=0

have() { command -v "$1" >/dev/null 2>&1; }

echo "========================================"
echo " NCC CLI formatter validation"
echo "========================================"
echo "Root: $ROOT"
echo ""

# --------------------------------------------------------------------------
section() { echo ""; echo "== $* =="; }

section "1) CLI.md for every commands.nix"
n_ok=0
n_miss=0
while IFS= read -r cmd; do
  dir=$(dirname "$cmd")
  rel=${dir#"$ROOT/"}
  if [[ ! -f "$dir/CLI.md" ]]; then
    echo "MISSING CLI.md: $rel"
    fail=1
    n_miss=$((n_miss + 1))
  elif ! grep -qE '\*\*Status:\*\* `(todo|partial|compliant)`' "$dir/CLI.md"; then
    echo "BAD STATUS LINE: $rel/CLI.md"
    fail=1
    n_miss=$((n_miss + 1))
  else
    n_ok=$((n_ok + 1))
  fi
done < <(find "$ROOT/nixos/core" "$ROOT/nixos/modules" -name commands.nix -print | sort)
echo "OK: $n_ok · missing/bad: $n_miss"

section "2) SSOT docs present"
for f in \
  nixos/core/management/cli-formatter/doc/STANDARDS.md \
  nixos/core/management/cli-formatter/doc/COPY.md \
  nixos/core/management/cli-formatter/doc/CLI.md.template \
  nixos/core/management/cli-formatter/api.nix
do
  if [[ -f "$ROOT/$f" ]]; then
    echo "OK $f"
  else
    echo "MISSING $f"
    fail=1
  fi
done

section "3) Forbidden hardcoded formatter path (live Nix)"
hits=$(rg -n 'config\.core\.management\.cli-formatter' "$ROOT/nixos" --glob '*.nix' \
  --glob '!**/cli-formatter/doc/**' \
  --glob '!**/cli-formatter/template-config.nix' \
  2>/dev/null || true)
hits=$(echo "$hits" | grep -v '^\s*$' | grep -v ':[[:space:]]*#' || true)
if [[ -n "$hits" ]]; then
  echo "$hits"
  fail=1
else
  echo "OK"
fi

section "4) No private colors.nix outside cli-formatter"
# install-wizard/scripts/lib/colors.nix is a bridge that exports ui.colors — allowlisted
priv=$(find "$ROOT/nixos" -name 'colors.nix' \
  ! -path '*/cli-formatter/*' \
  ! -path '*/install-wizard/scripts/lib/colors.nix' \
  2>/dev/null || true)
if [[ -n "$priv" ]]; then
  echo "$priv"
  fail=1
else
  echo "OK"
fi

section "5) Private ANSI (\\033 / \\e[) outside allowlist — HARD FAIL"
# Allow: formatter SSOT, GUI terminal glue, user shell PS1
allow_re='/(cli-formatter/|gui-engine/|shellInit/)'
suspects=$(rg -l '\\033\[|\\e\[' "$ROOT/nixos" --glob '*.nix' 2>/dev/null || true)
bad=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  if echo "$f" | grep -Eq "$allow_re"; then
    continue
  fi
  bad+="$f"$'\n'
done <<< "$suspects"
if [[ -n "$(echo "$bad" | sed '/^$/d')" ]]; then
  echo "$bad" | sed '/^$/d'
  fail=1
else
  echo "OK"
fi

section "6) Broken getModuleApi misuse"
# classic bug: config.${builtins.getModuleApi ...}
hits=$(rg -n 'config\.\$\{builtins\.getModuleApi|config\.\$\{.*getModuleApi' "$ROOT/nixos" --glob '*.nix' 2>/dev/null || true)
if [[ -n "$hits" ]]; then
  echo "$hits"
  fail=1
else
  echo "OK"
fi

section "7) High-traffic scripts must import getModuleApi \"cli-formatter\""
# Explicit allowlist of files that ship user-facing CLI chrome
required=(
  nixos/core/management/system-manager/handlers/system-update.nix
  nixos/core/management/system-manager/components/config-migration/check.nix
  nixos/core/management/system-manager/components/system-checks/scripts/postbuild-checks.nix
  nixos/core/management/system-manager/components/system-checks/scripts/prebuild-checks.nix
  nixos/core/management/module-manager/components/module-migration/runner.nix
  nixos/core/base/packages/scripts/ncc-packages.nix
  nixos/core/management/cli-registry/lib/utils.nix
  nixos/modules/infrastructure/stack-manager/handlers/stacks-fetch.nix
)
for rel in "${required[@]}"; do
  f="$ROOT/$rel"
  if [[ ! -f "$f" ]]; then
    echo "MISSING file: $rel"
    fail=1
    continue
  fi
  if rg -q 'getModuleApi\s*"cli-formatter"|getModuleApi '\''cli-formatter'\''' "$f"; then
    echo "OK $rel"
  else
    echo "NO formatter import: $rel"
    fail=1
  fi
done

section "8) Install-wizard colors must come from getModuleApi"
f="$ROOT/nixos/core/management/install-wizard/scripts/lib/colors.nix"
if rg -q 'getModuleApi "cli-formatter"' "$f" && rg -q 'ui\.colors|getModuleApi' "$f"; then
  echo "OK install-wizard colors.nix → formatter"
else
  echo "FAIL install-wizard colors.nix not wired to formatter"
  fail=1
fi

section "9) Nix parse smoke (key modules)"
if ! have nix-instantiate; then
  echo "SKIP (no nix-instantiate)"
  warn=1
else
  parse_files=(
    nixos/core/management/cli-formatter/api.nix
    nixos/core/management/cli-registry/lib/utils.nix
    nixos/core/management/system-manager/handlers/system-update.nix
    nixos/core/management/system-manager/components/config-migration/check.nix
    nixos/core/management/system-manager/components/system-checks/scripts/postbuild-checks.nix
    nixos/core/management/install-wizard/scripts/lib/colors.nix
    nixos/core/management/install-wizard/scripts/lib/logging.nix
    nixos/core/base/packages/scripts/ncc-packages.nix
    nixos/modules/infrastructure/stack-manager/handlers/stacks-fetch.nix
    nixos/modules/infrastructure/stack-manager/ui/tui/helpers.nix
  )
  for rel in "${parse_files[@]}"; do
    if nix-instantiate --parse "$ROOT/$rel" >/dev/null 2>&1; then
      echo "OK parse $rel"
    else
      echo "FAIL parse $rel"
      nix-instantiate --parse "$ROOT/$rel" 2>&1 | tail -3
      fail=1
    fi
  done
fi

section "10) Formatter API + colors.sh smoke build"
if ! have nix-build; then
  echo "SKIP (no nix-build)"
  warn=1
else
  if nix-build --no-out-link "$ROOT/tests/cli-formatter/smoke.nix" >/dev/null 2>"$ROOT/tests/cli-formatter/.smoke.err"; then
    echo "OK API shape + colors.sh + postbuild build"
    rm -f "$ROOT/tests/cli-formatter/.smoke.err"
  else
    echo "FAIL smoke build"
    tail -40 "$ROOT/tests/cli-formatter/.smoke.err" || true
    fail=1
  fi
fi

section "11) Flake-extras unit (related to system update dry-run)"
if [[ -x "$ROOT/tests/install-wizard/test-flake-extras.sh" ]]; then
  if bash "$ROOT/tests/install-wizard/test-flake-extras.sh"; then
    echo "OK flake-extras"
  else
    echo "FAIL flake-extras"
    fail=1
  fi
else
  echo "SKIP test-flake-extras.sh"
  warn=1
fi

section "12) Install-wizard packaging (stale checks/ + { pkgs }: leftovers)"
if [[ -x "$ROOT/tests/install-wizard/test-install-wizard-packaging.sh" ]]; then
  if bash "$ROOT/tests/install-wizard/test-install-wizard-packaging.sh"; then
    echo "OK install-wizard packaging"
  else
    echo "FAIL install-wizard packaging"
    fail=1
  fi
else
  echo "SKIP test-install-wizard-packaging.sh"
  warn=1
fi

section "13) No ui.messages splice inside one-line braces (bash ; } bug)"
# Antipattern: `fn() { ${ui.messages…}; }` or `|| { ${ui.messages…}; exit 1; }`
hits=$(rg -n '\|\|\s*\{\s*\$\{ui\.messages\.|\*\)\s*\$\{ui\.messages\.[a-z]+ "[^"]*"\}\s*;\s*exit|\w+\(\)\s*\{\s*\$\{ui\.messages\.' \
  "$ROOT/nixos" --glob '*.nix' 2>/dev/null || true)
if [[ -n "$hits" ]]; then
  echo "$hits"
  fail=1
else
  echo "OK"
fi

echo ""
echo "========================================"
if [[ "$fail" -ne 0 ]]; then
  echo "FAIL: automated CLI validation failed."
  echo "See tests/cli-formatter/MANUAL.md for what still needs a live host."
  exit 1
fi
echo "PASS: automated CLI validation OK."
if [[ "$warn" -ne 0 ]]; then
  echo "(some checks skipped — warnings above)"
fi
echo ""
echo "Automated = static rules + nix parse/build smoke."
echo "NOT covered: live \`ncc system update --dry-run\` on a real machine."
echo "→ tests/cli-formatter/MANUAL.md"
exit 0
