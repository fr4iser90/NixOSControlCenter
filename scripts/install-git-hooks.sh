#!/usr/bin/env bash
# Wire Git pre-commit → tests/run-gates.sh (like deepseek-harness postinstall).
# Idempotent. No Node/lefthook — plain Git.
#
# Called automatically from:
#   - .cursor/hooks (sessionStart)
#   - tests/run-gates.sh (self-heal)
# Manual: bash scripts/install-git-hooks.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "install-git-hooks: not a git repo — skip" >&2
  exit 0
fi

GIT_DIR="$(git rev-parse --git-dir)"
# Resolve to absolute (git-dir can be relative)
case "$GIT_DIR" in
  /*) ;;
  *) GIT_DIR="$ROOT/$GIT_DIR" ;;
esac

HOOK_SRC="$ROOT/.githooks/pre-commit"
if [[ ! -f "$HOOK_SRC" ]]; then
  echo "install-git-hooks: missing $HOOK_SRC" >&2
  exit 1
fi
chmod +x "$HOOK_SRC" 2>/dev/null || true

# Prefer core.hooksPath → .githooks (repo-tracked scripts).
current="$(git config --local --get core.hooksPath 2>/dev/null || true)"
want=".githooks"
if [[ "$current" != "$want" ]]; then
  if [[ -n "$current" && "$current" != "$want" ]]; then
    # Do not clobber a foreign hooksPath (e.g. another tool) unless forced.
    if [[ "${NCC_HOOKS_FORCE:-}" != "1" ]]; then
      echo "install-git-hooks: core.hooksPath already '$current' — leave it (NCC_HOOKS_FORCE=1 to override)" >&2
    else
      git config --local core.hooksPath "$want"
      echo "install-git-hooks: forced core.hooksPath=$want (was $current)"
    fi
  else
    git config --local core.hooksPath "$want"
    echo "install-git-hooks: set core.hooksPath=$want"
  fi
fi

# Also drop a thin wrapper into .git/hooks/pre-commit so commits still run
# gates if hooksPath is unset/overridden by something that ignores it.
HOOKS_DIR="$GIT_DIR/hooks"
mkdir -p "$HOOKS_DIR"
WRAPPER="$HOOKS_DIR/pre-commit"
MARKER="# NCC-managed pre-commit → .githooks/pre-commit"
if [[ -f "$WRAPPER" ]] && ! grep -q 'NCC-managed pre-commit' "$WRAPPER" 2>/dev/null; then
  if [[ "${NCC_HOOKS_FORCE:-}" != "1" ]]; then
    echo "install-git-hooks: existing .git/hooks/pre-commit not NCC-managed — leave it" >&2
  else
    cp -a "$WRAPPER" "$WRAPPER.ncc-bak.$(date +%s)" 2>/dev/null || true
    cat >"$WRAPPER" <<EOF
#!/usr/bin/env bash
$MARKER
exec bash "$HOOK_SRC" "\$@"
EOF
    chmod +x "$WRAPPER"
    echo "install-git-hooks: replaced .git/hooks/pre-commit (backup made)"
  fi
else
  cat >"$WRAPPER" <<EOF
#!/usr/bin/env bash
$MARKER
exec bash "$HOOK_SRC" "\$@"
EOF
  chmod +x "$WRAPPER"
fi

exit 0
