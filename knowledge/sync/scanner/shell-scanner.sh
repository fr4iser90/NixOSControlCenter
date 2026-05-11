#!/usr/bin/env bash
# knowledge/sync/scanner/shell-scanner.sh
# Scans shell/ directory, outputs changes vs shell.json
# Usage: shell-scanner.sh /path/to/NixOSControlCenter

set -euo pipefail

ROOT_DIR="${1:?Usage: shell-scanner.sh <root-dir>}"
KNOWLEDGE_DIR="$ROOT_DIR/knowledge"
SHELL_JSON="$KNOWLEDGE_DIR/domains/shell.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[shell-scanner]${NC} $1"; }
log_error() { echo -e "${RED}[shell-scanner]${NC} $1"; }

SHELL_DIR="$ROOT_DIR/shell"
if [ ! -d "$SHELL_DIR" ]; then
    log_error "shell/ directory not found at $SHELL_DIR"
    exit 1
fi

log_info "Scanning shell/ tree..."

# List all files with descriptions
find "$SHELL_DIR" -type f \( -name "*.sh" -o -name "*.nix" \) | sort | while IFS= read -r file; do
    rel_path="${file#$SHELL_DIR/}"
    file_size=$(wc -c < "$file")
    echo "FILE:$rel_path:${file_size}b"
done

log_info "Shell scan complete."
