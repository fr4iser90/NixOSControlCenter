#!/usr/bin/env bash
# HARD GATE — Nix syntax must parse with the parser the build actually uses.
#
# Why this exists: `nix build` / `nix eval` use Nix's current parser, while
# `nix-instantiate --parse` (used by older checks) is the legacy one and is more
# permissive. `foo.bar or -1` parsed fine there and broke the live system build
# with "syntax error, unexpected '-'" — the sentinel must be written `or (-1)`.
#
# Covers:
#   1) negative literal right after `or` anywhere in nixos/ (never parses)
#   2) build-parser syntax check for every .nix changed vs HEAD
#      (tree-wide is not checked: 58 pre-existing files under nixos/ are not
#       standalone-parseable at all — dead/template fragments — see git blame)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAIL=0

pass() { echo "  PASS: $*"; }
fail() { echo "  FAIL: $*"; FAIL=1; }

echo "=== validate-nix-parse (build-parser syntax) ==="

# ── 1) `or -1` footgun ───────────────────────────────────────────────────────
echo "== 1/2  negative literal after \`or\` =="
BAD_OR=$(grep -rnE '\bor[[:space:]]+-[0-9]' --include='*.nix' "$ROOT/nixos" || true)
if [[ -n "$BAD_OR" ]]; then
  echo "$BAD_OR" | sed "s|$ROOT/||;s/^/    /"
  fail "expr or -N is a Nix syntax error — write (expr or (-N))"
else
  pass "no 'or -N' literals in nixos/"
fi

# ── 2) build-parser parse of changed .nix files ──────────────────────────────
echo "== 2/2  nix eval parse of changed .nix =="
if ! command -v nix >/dev/null 2>&1; then
  fail "nix not available — cannot verify build-parser syntax"
else
  CHANGED=$(
    {
      git -C "$ROOT" diff --name-only HEAD -- nixos
      git -C "$ROOT" ls-files --others --exclude-standard -- nixos
    } 2>/dev/null | grep '\.nix$' | sort -u || true
  )
  if [[ -z "$CHANGED" ]]; then
    pass "no changed .nix files to parse"
  else
    PARSED=0
    CHECKED=0
    while IFS= read -r rel; do
      [[ -n "$rel" && -f "$ROOT/$rel" ]] || continue
      CHECKED=$((CHECKED + 1))
      OUT=$(nix eval --offline -f "$ROOT/$rel" 2>&1) || true
      # Only syntax errors matter here; the file may legitimately fail to eval
      # (module functions need args, lookups need nixpkgs) — that is not this gate.
      if [[ "$OUT" == *"syntax error"* ]]; then
        echo "    $rel"
        echo "$OUT" | head -6 | sed 's/^/      /'
        fail "build parser rejected $rel"
      else
        PARSED=$((PARSED + 1))
      fi
    done <<< "$CHANGED"
    if [[ "$FAIL" -eq 0 ]]; then
      pass "$PARSED/$CHECKED changed .nix parse with the build parser"
    fi
  fi
fi

echo ""
echo "=== validate-nix-parse summary ==="
if [[ "$FAIL" -ne 0 ]]; then
  echo "FAILED — nix build switch would break on the syntax above."
  exit 1
fi
echo "OK — no 'or -N' literals; changed nixos/*.nix parse with the build parser."
exit 0
