#!/usr/bin/env bash
# Cursor sessionStart — ensure Git pre-commit gates are wired (idempotent).
# stdin: Cursor hook JSON (ignored). stdout: optional additional_context JSON.
set -euo pipefail
# Drain stdin so Cursor does not get a broken pipe
cat >/dev/null || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -x "$ROOT/scripts/install-git-hooks.sh" ]] || [[ -f "$ROOT/scripts/install-git-hooks.sh" ]]; then
  bash "$ROOT/scripts/install-git-hooks.sh" >/dev/null 2>&1 || true
fi

# Minimal valid response (sessionStart is fire-and-forget for blocking)
printf '%s\n' '{}'
exit 0
