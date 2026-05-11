#!/usr/bin/env bash
# knowledge/sync/generator/knowledge-index-gen.sh
# Regenerates knowledge/index.json with updated sync timestamps
# Usage: knowledge-index-gen.sh /path/to/NixOSControlCenter /path/to/knowledge

set -euo pipefail

ROOT_DIR="${1:?Usage: knowledge-index-gen.sh <root-dir> <knowledge-dir>}"
KNOWLEDGE_DIR="${2:?Usage: knowledge-index-gen.sh <root-dir> <knowledge-dir>}"
INDEX_FILE="$KNOWLEDGE_DIR/index.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[index-gen]${NC} $1"; }

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Build arrays of available skills, contexts, domains, modules
SKILLS="[]"
if [ -d "$KNOWLEDGE_DIR/skills" ]; then
    SKILLS=$(find "$KNOWLEDGE_DIR/skills" -name "*.json" -type f | sort | while read -r f; do
        name=$(basename "$f" .json)
        tokens=$(wc -c < "$f")
        echo "{\"id\":\"$name\",\"file\":\"skills/$name.json\",\"tokens\":\"~$((tokens / 5)) tokens\",\"loaded\":false}"
    done | jq -s .)
fi

CONTEXTS="[]"
if [ -d "$KNOWLEDGE_DIR/context" ]; then
    CONTEXTS=$(find "$KNOWLEDGE_DIR/context" -name "*.json" -type f | sort | while read -r f; do
        name=$(basename "$f" .json)
        tokens=$(wc -c < "$f")
        echo "{\"id\":\"$name\",\"file\":\"context/$name.json\",\"tokens\":\"~$((tokens / 5)) tokens\",\"loaded\":false}"
    done | jq -s .)
fi

DOMAINS="[]"
if [ -d "$KNOWLEDGE_DIR/domains" ]; then
    DOMAINS=$(find "$KNOWLEDGE_DIR/domains" -name "*.json" -type f | sort | while read -r f; do
        name=$(basename "$f" .json)
        tokens=$(wc -c < "$f")
        echo "{\"id\":\"$name\",\"file\":\"domains/$name.json\",\"tokens\":\"~$((tokens / 5)) tokens\",\"loaded\":false}"
    done | jq -s .)
fi

MODULES="[]"
if [ -d "$KNOWLEDGE_DIR/modules" ]; then
    MODULES=$(find "$KNOWLEDGE_DIR/modules" -name "*.json" -type f | sort | while read -r f; do
        name=$(basename "$f" .json)
        tokens=$(wc -c < "$f")
        echo "{\"id\":\"$name\",\"file\":\"modules/$name.json\",\"tokens\":\"~$((tokens / 5)) tokens\",\"loaded\":false}"
    done | jq -s .)
fi

# Update index.json
jq \
    --arg timestamp "$TIMESTAMP" \
    --arg gitHash "$GIT_HASH" \
    --argjson skills "$SKILLS" \
    --argjson contexts "$CONTEXTS" \
    --argjson domains "$DOMAINS" \
    --argjson modules "$MODULES" \
    '.
        ._lastSyncedWithGit = $timestamp |
        ._gitHash = $gitHash |
        .skills = $skills |
        .contexts = $contexts |
        .domains = $domains |
        .modules = $modules
    ' "$INDEX_FILE" > "${INDEX_FILE}.tmp" && mv "${INDEX_FILE}.tmp" "$INDEX_FILE"

log_info "Index updated: hash=$GIT_HASH timestamp=$TIMESTAMP"
log_info "  Skills: $(echo "$SKILLS" | jq 'length') files"
log_info "  Contexts: $(echo "$CONTEXTS" | jq 'length') files"
log_info "  Domains: $(echo "$DOMAINS" | jq 'length') files"
log_info "  Modules: $(echo "$MODULES" | jq 'length') files"
