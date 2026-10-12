#!/usr/bin/env bash
# ncc-assistant Python suite — permission ladder, wrapper env, notifications, companion probes.
#
# Plain unittest/pytest: no PySide6 needed (the Qt surfaces live in tests/gui/).
# Interpreter: NCC_ASSISTANT_PYTHON=/path/to/bin/python, else python3.
# pytest is required, not optional — several files are bare test functions, so unittest
# discovery alone would report green while never running them.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PYTHON="${NCC_ASSISTANT_PYTHON:-python3}"

if [[ ! -x "$PYTHON" ]] && ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "FAIL: $PYTHON not found (set NCC_ASSISTANT_PYTHON to a python with pytest)"
  exit 1
fi

if ! "$PYTHON" -m pytest --version >/dev/null 2>&1; then
  echo "FAIL: $PYTHON has no pytest — install the python-dev package set"
  echo "      or point NCC_ASSISTANT_PYTHON at an interpreter that has it."
  exit 1
fi

echo "assistant python: $PYTHON ($("$PYTHON" -m pytest --version 2>&1 | head -1))"
"$PYTHON" -m pytest "${ROOT}/tests/ncc-assistant" -q

echo "OK — ncc-assistant-python gate green."
