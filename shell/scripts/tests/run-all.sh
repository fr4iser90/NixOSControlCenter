#!/usr/bin/env bash
# Run all installer shell tests.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo ">>> test-presets-dry-run.sh"
bash "$DIR/test-presets-dry-run.sh"
echo
echo ">>> test-installer-full.sh"
bash "$DIR/test-installer-full.sh"
echo
echo ">>> test-installer-remaining.sh"
bash "$DIR/test-installer-remaining.sh"
echo
echo ">>> test-docker-mode.sh"
bash "$DIR/test-docker-mode.sh"
echo
echo ">>> test-resolve-pins.sh"
bash "$DIR/test-resolve-pins.sh"
echo
echo "All installer tests passed."
