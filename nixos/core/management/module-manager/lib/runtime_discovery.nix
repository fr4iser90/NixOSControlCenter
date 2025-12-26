# Runtime Module Discovery - DATA COLLECTION ONLY
# Scans filesystem at runtime, parses configs, returns module data as JSON/lines

{ lib, pkgs, ... }:

let
  # Runtime discovery script that outputs module data
  runtimeDiscoveryScript = ''
    # PURE DATA COLLECTION - NO UI!

    set -euo pipefail

    # Configuration
    readonly MODULES_BASE="/etc/nixos"
    readonly CONFIGS_BASE="/etc/nixos/configs"

    # Parse Nix enable value from config file
    parse_nix_enable() {
        local file="$1"

        if [[ ! -f "$file" ]]; then
            echo "null"  # Not configured
            return
        fi

        # Extract enable value using regex
        local enable_value
        enable_value=$(grep -oP 'enable\s*=\s*\K(true|false)' "$file" | head -1 || echo "")

        if [[ -n "$enable_value" ]]; then
            echo "$enable_value"
        else
            echo "null"  # Malformed config
        fi
    }

    # Extract description from module files
    extract_description() {
        local module_dir="$1"
        local module_name="$2"

        # Try README.md first
        if [[ -f "$module_dir/README.md" ]]; then
            local description
            description=$(head -20 "$module_dir/README.md" | grep -A1 '^#' | tail -1 | sed 's/^#*\s*//' | xargs || echo "")
            if [[ -n "$description" ]]; then
                echo "$description"
                return
            fi
        fi

        # Try options.nix
        if [[ -f "$module_dir/options.nix" ]]; then
            local description
            description=$(grep -oP 'mkEnableOption\s*"\K[^"]*' "$module_dir/options.nix" | head -1 || echo "")
            if [[ -n "$description" ]]; then
                echo "$description"
                return
            fi
        fi

        # Fallback
        echo "Module for $module_name"
    }

    # Discover all valid modules (JSON format - Bubble Tea)
    discover_modules() {
        discover_modules_json
    }

    # Discover modules in JSON format for Bubble Tea TUI
    discover_modules_json() {
        echo "["

        local first=true
        find "$MODULES_BASE/modules" "$MODULES_BASE/core" -name "default.nix" -type f 2>/dev/null | while read -r default_file; do
            local module_dir
            module_dir=$(dirname "$default_file")

            # Must have options.nix
            local options_file="$module_dir/options.nix"
            if [[ ! -f "$options_file" ]]; then
                continue
            fi

            # Extract metadata
            local module_name
            module_name=$(basename "$module_dir")

            local category
            if [[ "$module_dir" == */core/* ]]; then
                category=$(echo "$module_dir" | sed "s|$MODULES_BASE/core||" | sed 's|^/||' | tr '/' '.')
                category="core${category:+.$category}"
            else
                category=$(echo "$module_dir" | sed "s|$MODULES_BASE/modules||" | sed 's|^/||' | tr '/' '.')
                category="modules${category:+.$category}"
            fi

            # Get real status from config
            local config_file="$CONFIGS_BASE/$module_name/config.nix"
            local enabled
            enabled=$(parse_nix_enable "$config_file")

            # Get description
            local description
            description=$(extract_description "$module_dir" "$module_name")

            # Get version
            local version
            version=$(grep -oP '_version\s*=\s*"\K[^"]*' "$options_file" 2>/dev/null | head -1 || echo "1.0")

            # Convert status for JSON
            local status
            case "$enabled" in
                "true") status="enabled" ;;
                "false") status="disabled" ;;
                *) status="unknown" ;;
            esac

            # Fallback description
            if [[ -z "$description" ]]; then
                description="No description available"
            fi

            # JSON separator
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi

            # Output JSON object
            cat << EOF
{
  "id": "$module_name",
  "name": "$module_name",
  "description": "$description",
  "category": "$category",
  "status": "$status",
  "version": "$version",
  "path": "$module_dir"
}
EOF
        done

        echo "]"
    }

    # DEBUG OUTPUT - Only when explicitly requested (DEBUG=1)
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "=== DEBUG: Module Discovery ===" >&2
        echo "MODULES_BASE: $MODULES_BASE" >&2
        echo "CONFIGS_BASE: $CONFIGS_BASE" >&2
        echo "Searching in: $MODULES_BASE" >&2
        echo "" >&2

        echo "Found and parsed modules:" >&2
        discover_modules | while read -r line; do
            echo "  $line" >&2
        done

        echo "" >&2
        echo "=== END DEBUG ===" >&2
        echo "" >&2
    fi

    # Main function - just output the fzf lines directly
    main() {
        # Always output JSON for Bubble Tea TUI
        discover_modules
    }

    # Run main
    main
  '';

in {
  # The discovery script
  runtimeDiscovery = runtimeDiscoveryScript;

  # Helper to get raw JSON data
  getJsonData = let
    script = pkgs.writeScript "get-module-data" ''
      ${runtimeDiscoveryScript}
      # Override main to output JSON
      main() {
          discover_modules
      }
      main
    '';
  in script;

  # Helper to get module menu lines
  getModuleLines = let
    script = pkgs.writeScript "get-module-lines" runtimeDiscoveryScript;
  in script;
}
