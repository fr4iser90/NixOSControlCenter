#!/usr/bin/env bash
# GUI Python smoke — imports, domain pages, FS status, session UX, hot-path.
#
# Qt tests need PySide6. NCC does **not** put it on system python3 — it lives in
# the gui-engine pythonEnv. Resolution order:
#   1) NCC_GUI_PYTHON=/path/to/bin/python
#   2) python from `ncc-gui` wrapper on PATH (deployed host)
#   3) nix-build tests/gui/python-env.nix (repo, reproducible)
#   4) skip Qt-only tests (AST/compile still run)
#
# Optional soak: NCC_GUI_SOAK=1 bash tests/gui/validate-gui-python.sh
# Skip nix-build: NCC_GUI_SKIP_NIX_PYTHON=1
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PYTHONPATH="${ROOT}/nixos/core/management/gui-engine/python${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONPATH="${ROOT}/nixos/modules/specialized/ncc-assistant/python${PYTHONPATH:+:$PYTHONPATH}"
PYTHONPATH="${ROOT}/tests/gui${PYTHONPATH:+:$PYTHONPATH}"
# Domain page smoke must not touch live /etc/nixos or open modal dialogs.
export NIXOS_DIR="${NIXOS_DIR:-$ROOT/nixos}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"

resolve_python() {
  if [[ -n "${NCC_GUI_PYTHON:-}" && -x "${NCC_GUI_PYTHON}" ]]; then
    echo "${NCC_GUI_PYTHON}"
    return 0
  fi
  if command -v ncc-gui >/dev/null 2>&1; then
    local wrap py
    wrap="$(command -v ncc-gui)"
    py="$(sed -n 's/.*exec \(.*\)\/bin\/python .*/\1\/bin\/python/p' "$wrap" | head -1)"
    if [[ -n "$py" && -x "$py" ]]; then
      echo "$py"
      return 0
    fi
  fi
  if [[ "${NCC_GUI_SKIP_NIX_PYTHON:-}" != "1" ]] && command -v nix-build >/dev/null 2>&1; then
    local out
    out="$(nix-build --no-out-link "${ROOT}/tests/gui/python-env.nix" 2>/dev/null)" || out=""
    if [[ -n "$out" && -x "${out}/bin/python" ]]; then
      echo "${out}/bin/python"
      return 0
    fi
  fi
  return 1
}

PYTHON=python3
HAS_QT=0
if PY_RESOLVED="$(resolve_python)"; then
  PYTHON="$PY_RESOLVED"
  if "$PYTHON" -c "import PySide6" 2>/dev/null; then
    HAS_QT=1
    echo "GUI python: $PYTHON (PySide6 ok)"
  else
    echo "WARN: $PYTHON has no PySide6 — Qt tests will skip"
  fi
else
  echo "WARN: no NCC GUI python found — Qt tests will skip"
  echo "  hint: export NCC_GUI_PYTHON=\$(nix-build --no-out-link tests/gui/python-env.nix)/bin/python"
fi

run() {
  echo "→ $*"
  "$PYTHON" "$@"
}

run "${ROOT}/tests/gui/test_settings_import_smoke.py"
run "${ROOT}/tests/gui/test_domain_pages_smoke.py"
run "${ROOT}/tests/gui/test_gui_ncc_argv.py"
run "${ROOT}/tests/gui/test_domain_fs_status.py"
run "${ROOT}/tests/gui/test_session_ux.py"
run "${ROOT}/tests/gui/test_hot_path_perf.py"
run "${ROOT}/tests/gui/test_dialogs_copy.py"

if [[ "$HAS_QT" -eq 1 ]]; then
  run "${ROOT}/tests/gui/test_reload_generation.py"
else
  echo "SKIP: test_reload_generation.py (no PySide6 — see resolve_python)"
fi

if [[ "${NCC_GUI_SOAK:-}" =~ ^(1|true|yes)$ ]]; then
  if [[ "$HAS_QT" -eq 1 ]]; then
    run "${ROOT}/tests/gui/test_gui_soak.py"
  else
    echo "SKIP: test_gui_soak.py (needs PySide6)"
  fi
fi

echo "OK — gui-python gate green."
