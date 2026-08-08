# Runtime Module Discovery - DATA COLLECTION ONLY
# Scans filesystem at runtime, parses configs, returns module JSON array on stdout.

{ lib, pkgs, ... }:

let
  # bash ''${...} → Nix ''''${...}
  runtimeDiscoveryScript = ''
    set -euo pipefail

    readonly MODULES_BASE="''${NCC_MODULES_BASE:-/etc/nixos}"
    readonly CONFIGS_BASE="''${NCC_CONFIGS_BASE:-$MODULES_BASE/systemConfig}"
    readonly MONOLITH_FILE="''${NCC_MONOLITH_FILE:-$MODULES_BASE/systemConfig.nix}"
    readonly JQ="${pkgs.jq}/bin/jq"
    readonly NIX_INSTANTIATE="${pkgs.nix}/bin/nix-instantiate"

    parse_nix_enable() {
      local file="$1"
      if [[ ! -f "$file" ]]; then
        echo "null"
        return 0
      fi
      local enable_value=""
      enable_value=$(grep -oE 'enable[[:space:]]*=[[:space:]]*(true|false)' "$file" 2>/dev/null \
        | head -1 | grep -oE 'true|false' || true)
      if [[ -n "$enable_value" ]]; then
        echo "$enable_value"
      else
        echo "null"
      fi
      return 0
    }

    parse_monolith_enable() {
      local dotted="$1"
      if [[ ! -f "$MONOLITH_FILE" ]]; then
        echo "null"
        return 0
      fi
      local expr out
      expr="let c = import $MONOLITH_FILE; in (c.''${dotted}.enable or null)"
      out=$("$NIX_INSTANTIATE" --eval --strict -E "$expr" 2>/dev/null | tr -d '[:space:]' || true)
      case "$out" in
        true|false) echo "$out" ;;
        *) echo "null" ;;
      esac
      return 0
    }

    extract_description() {
      local module_dir="$1"
      local module_name="$2"
      local description=""

      if [[ -f "$module_dir/README.md" ]]; then
        description=$(awk '/^# /{getline; gsub(/^#+[[:space:]]*/,""); print; exit}' "$module_dir/README.md" 2>/dev/null || true)
        description=$(printf '%s' "$description" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$description" ]]; then
          printf '%s\n' "$description"
          return 0
        fi
      fi

      if [[ -f "$module_dir/options.nix" ]]; then
        description=$(grep -oE 'mkEnableOption[[:space:]]*"[^"]+"' "$module_dir/options.nix" 2>/dev/null \
          | head -1 | sed 's/.*"\([^"]*\)"/\1/' || true)
        if [[ -n "$description" ]]; then
          printf '%s\n' "$description"
          return 0
        fi
      fi

      echo "Module for $module_name"
      return 0
    }

    resolve_enable() {
      local rel_path="$1"
      local domain="$2"
      local config_file="$CONFIGS_BASE/$rel_path/config.nix"
      local enabled
      enabled=$(parse_nix_enable "$config_file")
      if [[ "$enabled" == "null" ]]; then
        local dotted
        dotted=$(printf '%s' "$rel_path" | tr '/' '.')
        enabled=$(parse_monolith_enable "$dotted")
      fi
      if [[ "$enabled" == "null" ]]; then
        if [[ "$domain" == "core" ]]; then
          echo "true"
        else
          echo "false"
        fi
      else
        echo "$enabled"
      fi
      return 0
    }

    emit_module() {
      local module_dir="$1"
      local domain="$2"
      local root="$3"

      local options_file="$module_dir/options.nix"
      [[ -f "$options_file" ]] || return 0

      local module_name
      module_name=$(basename "$module_dir")

      local rel
      rel="''${module_dir#"$root"/}"
      [[ "$rel" != "$module_dir" && -n "$rel" ]] || return 0

      local category enabled status description version
      category="$domain.$(printf '%s' "$rel" | tr '/' '.')"
      enabled=$(resolve_enable "$domain/$rel" "$domain")
      case "$enabled" in
        true) status="enabled" ;;
        false) status="disabled" ;;
        *) status="unknown" ;;
      esac

      description=$(extract_description "$module_dir" "$module_name")
      version=$(grep -oE '_version[[:space:]]*=[[:space:]]*"[^"]+"' "$options_file" 2>/dev/null \
        | head -1 | sed 's/.*"\([^"]*\)"/\1/' || true)
      [[ -n "$version" ]] || version="1.0"

      "$JQ" -n \
        --arg id "$module_name" \
        --arg name "$module_name" \
        --arg description "$description" \
        --arg category "$category" \
        --arg status "$status" \
        --arg version "$version" \
        --arg path "$module_dir" \
        --arg scope "$domain" \
        '{id:$id,name:$name,description:$description,category:$category,status:$status,version:$version,path:$path,scope:$scope}'
      return 0
    }

    discover_modules_json() {
      local ndjson root domain default_file
      ndjson=$(mktemp)
      # Always clean up; do not use RETURN trap (clashes when embedded).
      # shellcheck disable=SC2064
      trap "rm -f '$ndjson'" EXIT

      if [[ ! -d "$MODULES_BASE" ]]; then
        echo "[]"
        return 0
      fi

      for domain in core modules; do
        root="$MODULES_BASE/$domain"
        [[ -d "$root" ]] || continue
        # find may exit 1 on permission errors — never abort discovery
        while IFS= read -r default_file; do
          [[ -n "$default_file" ]] || continue
          emit_module "$(dirname "$default_file")" "$domain" "$root" >> "$ndjson" || true
        done < <(find "$root" -name default.nix -type f 2>/dev/null || true)
      done

      if [[ ! -s "$ndjson" ]]; then
        echo "[]"
        return 0
      fi

      "$JQ" -s 'sort_by(
        (if .scope == "core" then 0 else 1 end),
        (.name | ascii_downcase)
      )' "$ndjson"
      return 0
    }

    if [[ "''${DEBUG:-0}" == "1" ]]; then
      echo "MODULES_BASE=$MODULES_BASE" >&2
      echo "CONFIGS_BASE=$CONFIGS_BASE" >&2
    fi

    discover_modules_json
  '';

  discoveryBin = pkgs.writeShellScriptBin "ncc-modules-discover" runtimeDiscoveryScript;

in {
  runtimeDiscovery = runtimeDiscoveryScript;
  inherit discoveryBin;

  getJsonData = pkgs.writeScript "get-module-data" ''
    #!${pkgs.bash}/bin/bash
    ${runtimeDiscoveryScript}
  '';

  getModuleLines = pkgs.writeScript "get-module-lines" ''
    #!${pkgs.bash}/bin/bash
    ${runtimeDiscoveryScript}
  '';
}
