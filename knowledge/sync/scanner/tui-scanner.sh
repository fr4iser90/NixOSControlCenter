#!/usr/bin/env bash
# knowledge/sync/scanner/tui-scanner.sh
# Scans tui/ directories across nixos/ and docs/, outputs changes
# Usage: tui-scanner.sh /path/to/NixOSControlCenter

set -euo pipefail

ROOT_DIR="${1:?Usage: tui-scanner.sh <root-dir>}"
KNOWLEDGE_DIR="$ROOT_DIR/knowledge"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[tui-scanner]${NC} $1"; }

# Find all tui-related files across the project
log_info "Scanning tui/ directories..."

# tui-engine
if [ -d "$ROOT_DIR/nixos/core/management/tui-engine" ]; then
    echo "TUI_ENGINE:present"
    find "$ROOT_DIR/nixos/core/management/tui-engine" -type f -name "*.nix" | sort | while read -r f; do
        rel="${f#$ROOT_DIR/}"
        echo "  FILE:$rel"
    done
else
    echo "TUI_ENGINE:missing"
fi

# docs/tui
if [ -d "$ROOT_DIR/docs/tui" ]; then
    echo "DOCS_TUI:present"
    find "$ROOT_DIR/docs/tui" -type f -name "*.md" | sort | while read -r f; do
        rel="${f#$ROOT_DIR/}"
        echo "  FILE:$rel"
    done
else
    echo "DOCS_TUI:missing"
fi

# Module TUI integrations
echo "MODULE_TUI:"
find "$ROOT_DIR/nixos" -path "*/ui/tui/*.nix" -type f 2>/dev/null | sort | while read -r f; do
    rel="${f#$ROOT_DIR/}"
    module_dir=$(echo "$rel" | sed 's|/ui/tui/.*||')
    echo "  $module_dir → $rel"
done

log_info "TUI scan complete."
