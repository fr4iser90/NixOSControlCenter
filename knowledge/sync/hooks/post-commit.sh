#!/usr/bin/env bash
# knowledge/sync/hooks/post-commit.sh
# Git post-commit hook — detects changes, runs scanners, regenerates affected JSON files
#
# Install: cp knowledge/sync/hooks/post-commit.sh .git/hooks/post-commit
# chmod +x .git/hooks/post-commit

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
KNOWLEDGE_DIR="$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[knowledge]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[knowledge]${NC} $1"; }
log_error() { echo -e "${RED}[knowledge]${NC} $1"; }

# Get changed files since last commit
if ! git diff --quiet HEAD~1 2>/dev/null; then
    CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || true)
else
    log_warn "No previous commit to diff against. Skipping knowledge update."
    exit 0
fi

if [ -z "$CHANGED_FILES" ]; then
    log_info "No file changes detected. Skipping."
    exit 0
fi

# Determine which domains need updating
NEED_NIXOS=false
NEED_SHELL=false
NEED_CUSTOM=false

while IFS= read -r file; do
    case "$file" in
        nixos/*) NEED_NIXOS=true ;;
        shell/*) NEED_SHELL=true ;;
        nixos/custom/*) NEED_CUSTOM=true ;;
    esac
done <<< "$CHANGED_FILES"

# Run affected scanners
if $NEED_NIXOS; then
    log_info "Scanning nixos/ for changes..."
    "$SCRIPT_DIR/scanner/nixos-scanner.sh" "$ROOT_DIR" || log_error "nixos scanner failed"
fi

if $NEED_SHELL; then
    log_info "Scanning shell/ for changes..."
    "$SCRIPT_DIR/scanner/shell-scanner.sh" "$ROOT_DIR" || log_error "shell scanner failed"
fi

if $NEED_CUSTOM; then
    log_info "Scanning custom/ for changes..."
    "$SCRIPT_DIR/scanner/custom-scanner.sh" "$ROOT_DIR" || log_error "custom scanner failed"
fi

# If nixos changed, regenerate module registries
if $NEED_NIXOS; then
    log_info "Regenerating module registries..."
    "$SCRIPT_DIR/generator/module-registry-gen.sh" "$ROOT_DIR" || log_error "module registry generator failed"
fi

# Always update index.json timestamps if any scanner ran
if $NEED_NIXOS || $NEED_SHELL || $NEED_CUSTOM; then
    log_info "Updating knowledge index..."
    "$SCRIPT_DIR/generator/knowledge-index-gen.sh" "$ROOT_DIR" "$KNOWLEDGE_DIR" || log_error "index generator failed"
fi

log_info "Knowledge sync complete."
