#!/usr/bin/env bash
# Thin wrapper: run GUI wizard, echo selection (same contract as select_setup_mode / fzf).
# Exit: 0 = selection on stdout, 1 = cancelled, 2 = GUI unavailable (caller may fall back to TUI)
# Homelab/Docker answers → $NCC_GUI_ANSWERS_FILE (must be set by caller or we create one)

set -euo pipefail

GUI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIZARD="${GUI_DIR}/install_wizard.py"

# shellcheck source=gui-lib.sh
source "${GUI_DIR}/gui-lib.sh"

if [[ ! -f "$WIZARD" ]]; then
  echo "GUI wizard missing: $WIZARD" >&2
  exit 2
fi

if ! ncc_gui_available; then
  echo "GUI unavailable (no display or tkinter)" >&2
  exit 2
fi

ncc_gui_ensure_answers_file

PYTHON_BIN="${NCC_PYTHON:-}"
if [[ -z "$PYTHON_BIN" ]]; then
  PYTHON_BIN="$(command -v python3)"
fi

set +e
selection="$("$PYTHON_BIN" "$WIZARD" --answers-file "$NCC_GUI_ANSWERS_FILE" 2>/tmp/ncc-gui-wizard.err)"
rc=$?
set -e

if [[ -f /tmp/ncc-gui-wizard.err ]]; then
  # Keep diagnostics on stderr for the operator
  grep -v '^NCC_GUI_ANSWERS_FILE=' /tmp/ncc-gui-wizard.err >&2 || true
fi

if [[ $rc -eq 0 && -n "$selection" ]]; then
  echo "$selection"
  exit 0
fi

exit "$rc"
