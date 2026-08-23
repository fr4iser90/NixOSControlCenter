#!/usr/bin/env bash
# GUI Python smoke — imports, dataclasses, domain page construction.
# Optional soak: NCC_GUI_SOAK=1 bash tests/gui/validate-gui-python.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PYTHONPATH="${ROOT}/nixos/core/management/gui-engine/python${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONPATH="${ROOT}/nixos/modules/specialized/ncc-assistant/python${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONPATH="${ROOT}/tests/gui${PYTHONPATH:+:$PYTHONPATH}"
python3 "${ROOT}/tests/gui/test_settings_import_smoke.py"
python3 "${ROOT}/tests/gui/test_domain_pages_smoke.py"
python3 "${ROOT}/tests/gui/test_gui_ncc_argv.py"
if [[ "${NCC_GUI_SOAK:-}" =~ ^(1|true|yes)$ ]]; then
  python3 "${ROOT}/tests/gui/test_gui_soak.py"
fi
