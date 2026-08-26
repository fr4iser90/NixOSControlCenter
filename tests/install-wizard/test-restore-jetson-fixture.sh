#!/usr/bin/env bash
# Validate jetson pre-NCC restore fixture parses as Nix.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nix-instantiate --parse "$DIR/fixtures/jetson-pre-ncc/flake.nix" >/dev/null
echo "OK: jetson-pre-ncc flake.nix parses"
