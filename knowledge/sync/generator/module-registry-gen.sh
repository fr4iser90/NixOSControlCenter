#!/usr/bin/env bash
# knowledge/sync/generator/module-registry-gen.sh
# Reads nixos/ tree structure and regenerates core-registry.json and optional-registry.json
# Usage: module-registry-gen.sh /path/to/NixOSControlCenter

set -euo pipefail

ROOT_DIR="${1:?Usage: module-registry-gen.sh <root-dir>}"
KNOWLEDGE_DIR="$ROOT_DIR/knowledge"
CORE_REG="$KNOWLEDGE_DIR/modules/core-registry.json"
OPT_REG="$KNOWLEDGE_DIR/modules/optional-registry.json"
NIXOS_DIR="$ROOT_DIR/nixos"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[registry-gen]${NC} $1"; }
log_error() { echo -e "${RED}[registry-gen]${NC} $1"; }

if ! command -v jq &>/dev/null; then
    log_error "jq is required. Install jq 1.6+."
    exit 1
fi

if [ ! -d "$NIXOS_DIR" ]; then
    log_error "nixos/ directory not found at $NIXOS_DIR"
    exit 1
fi

log_info "Regenerating module registries from nixos/ tree..."

# Detect git hash and timestamp
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Function to get files in a directory (top-level .nix files)
get_top_files() {
    local dir="$1"
    if [ -d "$dir" ]; then
        find "$dir" -maxdepth 1 -name "*.nix" -type f -exec basename {} \; | sort | jq -R . | jq -s .
    else
        echo "[]"
    fi
}

# Function to get subdirectories
get_subdirs() {
    local dir="$1"
    if [ -d "$dir" ]; then
        find "$dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | jq -R . | jq -s .
    else
        echo "[]"
    fi
}

# Function to get subdirs with .nix files (leaf subdirs)
get_leaf_subdirs() {
    local dir="$1"
    if [ -d "$dir" ]; then
        find "$dir" -mindepth 1 -maxdepth 1 -type d | while read -r d; do
            if find "$d" -maxdepth 1 -name "*.nix" -type f | grep -q .; then
                echo "$d"
            fi
        done | sed "s|^$dir/||" | sort | jq -R . | jq -s .
    else
        echo "[]"
    fi
}

# Function to get description from doc/README.md or default to name
get_description() {
    local dir="$1"
    local name="$2"
    if [ -f "$dir/doc/README.md" ]; then
        head -5 "$dir/doc/README.md" | grep -i "^#\|description\|purpose" | head -1 | sed 's/^#*\s*//' | tr -d '"' || echo "$name"
    else
        echo "$name"
    fi
}

# Generate core registry
log_info "Generating core-registry.json..."
CORE_BASE=$(mktemp)
CORE_MGT=$(mktemp)

# Process core/base modules
echo "{" > "$CORE_BASE"
first=true
for mod_dir in "$NIXOS_DIR/core/base"/*/; do
    if [ ! -d "$mod_dir" ]; then continue; fi
    mod_name=$(basename "$mod_dir")

    if ! $first; then echo "," >> "$CORE_BASE"; fi
    first=false

    files=$(get_top_files "$mod_dir")
    leaf_subdirs=$(get_leaf_subdirs "$mod_dir")
    description=$(get_description "$mod_dir" "$mod_name")

    printf '  "%s": {\n    "path": "nixos/core/base/%s",\n    "files": %s,\n    "subdirs": %s,\n    "description": "%s"\n  }' \
        "$mod_name" "$mod_name" "$files" "$leaf_subdirs" "$description" >> "$CORE_BASE"
done
echo "" >> "$CORE_BASE"
echo "}" >> "$CORE_BASE"

# Process core/management modules
echo "{" > "$CORE_MGT"
first=true
for mod_dir in "$NIXOS_DIR/core/management"/*/; do
    if [ ! -d "$mod_dir" ]; then continue; fi
    mod_name=$(basename "$mod_dir")

    if ! $first; then echo "," >> "$CORE_MGT"; fi
    first=false

    files=$(get_top_files "$mod_dir")
    leaf_subdirs=$(get_leaf_subdirs "$mod_dir")
    description=$(get_description "$mod_dir" "$mod_name")

    printf '  "%s": {\n    "path": "nixos/core/management/%s",\n    "files": %s,\n    "subdirs": %s,\n    "description": "%s"\n  }' \
        "$mod_name" "$mod_name" "$files" "$leaf_subdirs" "$description" >> "$CORE_MGT"
done
echo "" >> "$CORE_MGT"
echo "}" >> "$CORE_MGT"

# Combine into final core registry
jq -n \
    --argjson base "$(cat "$CORE_BASE")" \
    --argjson management "$(cat "$CORE_MGT")" \
    --arg lastScan "$TIMESTAMP" \
    '{
        "_schema": "ncc-modules/core-registry/1.0",
        "_version": "1.0.0",
        "_lastScan": $lastScan,
        "base": $base,
        "management": $management
    }' > "$CORE_REG"

rm -f "$CORE_BASE" "$CORE_MGT"

# Generate optional registry
log_info "Generating optional-registry.json..."
OPT_CATS=$(mktemp)
echo "{" > "$OPT_CATS"

first_cat=true
for cat_dir in "$NIXOS_DIR/modules"/*/; do
    if [ ! -d "$cat_dir" ]; then continue; fi
    cat_name=$(basename "$cat_dir")

    if ! $first_cat; then echo "," >> "$OPT_CATS"; fi
    first_cat=false

    printf '  "%s": {\n' "$cat_name" >> "$OPT_CATS"

    first_mod=true
    for mod_dir in "$cat_dir"/*/; do
        if [ ! -d "$mod_dir" ]; then continue; fi
        mod_name=$(basename "$mod_dir")

        if ! $first_mod; then echo "," >> "$OPT_CATS"; fi
        first_mod=false

        files=$(get_top_files "$mod_dir")
        leaf_subdirs=$(get_leaf_subdirs "$mod_dir")
        description=$(get_description "$mod_dir" "$mod_name")

        printf '    "%s": {\n      "path": "nixos/modules/%s/%s",\n      "files": %s,\n      "subdirs": %s,\n      "description": "%s"\n    }' \
            "$mod_name" "$cat_name" "$mod_name" "$files" "$leaf_subdirs" "$description" >> "$OPT_CATS"
    done

    echo "" >> "$OPT_CATS"
    echo "  }" >> "$OPT_CATS"
done

echo "}" >> "$OPT_CATS"

jq -n \
    --argjson content "$(cat "$OPT_CATS")" \
    --arg lastScan "$TIMESTAMP" \
    '{
        "_schema": "ncc-modules/optional-registry/1.0",
        "_version": "1.0.0",
        "_lastScan": $lastScan
    } * $content' > "$OPT_REG"

rm -f "$OPT_CATS"

log_info "Registry regeneration complete."
log_info "  Core modules: $(jq '.base | length' "$CORE_REG") base + $(jq '.management | length' "$CORE_REG") management"
log_info "  Optional modules: $(jq '[.[] | keys | length] | add' "$OPT_REG") across $(jq '[keys | length]' "$OPT_REG") categories"
