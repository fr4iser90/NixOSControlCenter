#!/usr/bin/env bash
# Module static validation suite
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo ">>> validate-no-hardcoded-paths.sh"
bash "$DIR/validate-no-hardcoded-paths.sh"
echo
echo ">>> validate-module-imports.sh"
bash "$DIR/validate-module-imports.sh"
echo "All module checks passed."
