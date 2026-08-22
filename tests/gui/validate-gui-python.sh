#!/usr/bin/env bash
# GUI Python smoke — imports, dataclasses, domain page construction.
# Run from repo root: bash tests/gui/validate-gui-python.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PYTHONPATH="${ROOT}/nixos/core/management/gui-engine/python${PYTHONPATH:+:$PYTHONPATH}"
export PYTHONPATH="${ROOT}/nixos/modules/specialized/ncc-assistant/python${PYTHONPATH:+:$PYTHONPATH}"
python3 "${ROOT}/tests/gui/test_settings_import_smoke.py"
python3 "${ROOT}/tests/gui/test_domain_pages_smoke.py"
