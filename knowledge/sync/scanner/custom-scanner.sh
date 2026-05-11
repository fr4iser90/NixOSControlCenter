#!/usr/bin/env bash
# knowledge/sync/scanner/custom-scanner.sh
# Scans nixos/custom/ directory, outputs changes vs custom.json
# Usage: custom-scanner.sh /path/to/NixOSControlCenter

set -euo pipefail

ROOT_DIR="${1:?Usage: custom-scanner.sh <root-dir>}"
KNOWLEDGE_DIR="$ROOT_DIR/knowledge"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[custom-scanner]${NC} $1"; }

CUSTOM_DIR="$ROOT_DIR/nixos/custom"
if [ ! -d "$CUSTOM_DIR" ]; then
    log_info "custom/ directory not found. Skipping."
    exit 0
fi

log_info "Scanning nixos/custom/ tree..."

# List all .nix files in custom/
find "$CUSTOM_DIR" -maxdepth 1 -name "*.nix" -type f | sort | while IFS= read -r file; do
    fname=$(basename "$file")
    file_size=$(wc -c < "$file")
    echo "MODULE:$fname:${file_size}b"
done

log_info "Custom scan complete. $(find "$CUSTOM_DIR" -maxdepth 1 -name "*.nix" -type f | wc -l) modules found."
