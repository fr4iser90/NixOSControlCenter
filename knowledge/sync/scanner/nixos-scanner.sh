#!/usr/bin/env bash
# knowledge/sync/scanner/nixos-scanner.sh
# Scans nixos/ directory, outputs diff between current state and core-registry.json
# Usage: nixos-scanner.sh /path/to/NixOSControlCenter

set -euo pipefail

ROOT_DIR="${1:?Usage: nixos-scanner.sh <root-dir>}"
KNOWLEDGE_DIR="$ROOT_DIR/knowledge"
CORE_REGISTRY="$KNOWLEDGE_DIR/modules/core-registry.json"
OPTIONAL_REGISTRY="$KNOWLEDGE_DIR/modules/optional-registry.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[nixos-scanner]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[nixos-scanner]${NC} $1"; }
log_error() { echo -e "${RED}[nixos-scanner]${NC} $1"; }

# Check if jq is available
if ! command -v jq &>/dev/null; then
    log_error "jq is required but not installed. Install jq 1.6+."
    exit 1
fi

# Collect all .nix files in nixos/
NIXOS_DIR="$ROOT_DIR/nixos"
if [ ! -d "$NIXOS_DIR" ]; then
    log_error "nixos/ directory not found at $NIXOS_DIR"
    exit 1
fi

log_info "Scanning nixos/ tree..."

# Build a map of all known nix files: directory -> list of files
declare -A KNOWN_DIRS
declare -A KNOWN_FILES

while IFS= read -r nix_file; do
    rel_path="${nix_file#$NIXOS_DIR/}"
    dir=$(dirname "$rel_path")
    file=$(basename "$rel_path")

    KNOWN_DIRS["$dir"]=1

    # Categorize: core or optional
    if [[ "$dir" == core/* ]]; then
        # Extract module name: core/base/audio → base/audio → audio
        module_key=$(echo "$dir" | sed 's|core/||' | sed 's|^[^/]*/||' | sed 's|/.*||')
        category=$(echo "$dir" | sed 's|core/||' | cut -d/ -f1)
        subcat=$(echo "$dir" | sed 's|core/||' | cut -d/ -f2)

        # Build registry key path
        if [ "$subcat" = "$module_key" ]; then
            registry_path="core.$category.$module_key"
        else
            registry_path="core.$category.$subcat.$module_key"
        fi

        if [ -n "${KNOWN_FILES[$registry_path]+x}" ]; then
            KNOWN_FILES["$registry_path"]="${KNOWN_FILES[$registry_path]}|$file"
        else
            KNOWN_FILES["$registry_path"]="$file"
        fi
    elif [[ "$dir" == modules/* ]]; then
        # Extract module name: modules/infrastructure/vm → vm
        category=$(echo "$dir" | sed 's|modules/||' | cut -d/ -f1)
        module_key=$(echo "$dir" | sed 's|modules/||' | cut -d/ -f2)

        registry_path="modules.$category.$module_key"

        if [ -n "${KNOWN_FILES[$registry_path]+x}" ]; then
            KNOWN_FILES["$registry_path"]="${KNOWN_FILES[$registry_path]}|$file"
        else
            KNOWN_FILES["$registry_path"]="$file"
        fi
    fi
done < <(find "$NIXOS_DIR" -name "*.nix" -type f | sort)

# Check for new directories not in registry
CORE_DIRS=$(jq -r '.base | keys[]' "$CORE_REGISTRY" 2>/dev/null || true)
MGT_DIRS=$(jq -r '.management | keys[]' "$CORE_REGISTRY" 2>/dev/null || true)
INFRA_DIRS=$(jq -r '.infrastructure | keys[]' "$OPTIONAL_REGISTRY" 2>/dev/null || true)
SEC_DIRS=$(jq -r '.security | keys[]' "$OPTIONAL_REGISTRY" 2>/dev/null || true)
SPEC_DIRS=$(jq -r '.specialized | keys[]' "$OPTIONAL_REGISTRY" 2>/dev/null || true)
SYS_DIRS=$(jq -r '.system | keys[]' "$OPTIONAL_REGISTRY" 2>/dev/null || true)

ALL_REGISTRY_MODULES=()
while IFS= read -r m; do [ -n "$m" ] && ALL_REGISTRY_MODULES+=("base.$m"); done <<< "$CORE_DIRS"
while IFS= read -r m; do [ -n "$m" ] && ALL_REGISTRY_MODULES+=("management.$m"); done <<< "$MGT_DIRS"
while IFS= read -r m; do [ -n "$m" ] && ALL_REGISTRY_MODULES+=("infrastructure.$m"); done <<< "$INFRA_DIRS"
while IFS= read -r m; do [ -n "$m" ] && ALL_REGISTRY_MODULES+=("security.$m"); done <<< "$SEC_DIRS"
while IFS= read -r m; do [ -n "$m" ] && ALL_REGISTRY_MODULES+=("specialized.$m"); done <<< "$SPEC_DIRS"
while IFS= read -r m; do [ -n "$m" ] && ALL_REGISTRY_MODULES+=("system.$m"); done <<< "$SYS_DIRS"

# Check for new modules (directories with .nix files not in registry)
NEW_MODULES=()
for dir in "${!KNOWN_DIRS[@]}"; do
    # Get module name (last component of path)
    module_name=$(basename "$dir")
    # Check if this is a leaf module directory (has options.nix or default.nix)
    if [ -f "$NIXOS_DIR/$dir/options.nix" ] || [ -f "$NIXOS_DIR/$dir/default.nix" ]; then
        # Check if already in registry
        found=false
        for reg_mod in "${ALL_REGISTRY_MODULES[@]}"; do
            if [[ "$dir" == *"/$module_name" ]] || [[ "$dir" == "$module_name" ]]; then
                found=true
                break
            fi
        done
        if ! $found; then
            NEW_MODULES+=("$dir")
        fi
    fi
done

# Output scan results
if [ ${#NEW_MODULES[@]} -gt 0 ]; then
    log_warn "New modules detected: ${NEW_MODULES[*]}"
    for mod in "${NEW_MODULES[@]}"; do
        echo "NEW_MODULE:$mod"
    done
else
    log_info "No new modules detected."
fi

# Output file changes per module
for key in "${!KNOWN_FILES[@]}"; do
    IFS='|' read -ra files <<< "${KNOWN_FILES[$key]}"
    echo "MODULE:$key:${#files[@]}_files:${files[*]}"
done

# Output directory structure for subdirs
for dir in "${!KNOWN_DIRS[@]}"; do
    # Only list leaf subdirs (ones that contain .nix files)
    sub_nix=$(find "$NIXOS_DIR/$dir" -mindepth 1 -maxdepth 1 -type d -name "*.nix" 2>/dev/null || true)
    if [ -n "$sub_nix" ]; then
        echo "SUBDIR:$dir"
    fi
done

log_info "Scan complete. $(find "$NIXOS_DIR" -name "*.nix" -type f | wc -l) .nix files found."
