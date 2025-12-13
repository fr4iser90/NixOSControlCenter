# Module Manager Utility Functions
{ config, lib, pkgs, systemConfig, ... }:

let
  ui = config.core.cli-formatter.api;
  hostname = systemConfig.hostName;

  # Import discovery functions
  discovery = import ./discovery.nix { inherit lib; };

  # ALL modules discovered automatically
  allModules = discovery.discoverAllModules;

  # Helper: Generate config file for a module (PRESERVES EXISTING CONFIG!)
  updateModuleConfig = pkgs.writeShellScriptBin "update-module-config" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    module_name="$1"
    enable_value="$2"

    # Finde Modul-Info dynamisch
    ${lib.concatMapStringsSep "\n" (module: ''
      if [ "$module_name" = "${module.name}" ]; then
        config_file="${module.configFile}"
        enable_path="${module.enablePath}"
        category="${module.category}"
      fi
    '') allModules}

    if [ -z "$config_file" ]; then
      echo "Error: Module '$module_name' not found in available modules"
      exit 1
    fi

    # Create configs directory if needed
    mkdir -p "$(dirname "$config_file")"

    # If config doesn't exist, create minimal version
    if [ ! -f "$config_file" ]; then
      case "$category" in
        "system")
          module_short=$(basename "$config_file" "-config.nix")
          cat > "$config_file" <<EOF
{
  $module_short = {
    enable = $enable_value;
  };
}
EOF
          ;;
        "management")
          module_short=$(basename "$config_file" "-config.nix")
          cat > "$config_file" <<EOF
{
  $module_short = {
    enable = $enable_value;
  };
}
EOF
          ;;
        "features")
          # Features: features.category.module.enable
          IFS='.' read -r _ category_name module_name_short <<< "$module_name"
          cat > "$config_file" <<EOF
{
  features = {
    $category_name = {
      $module_name_short = {
        enable = $enable_value;
      };
    };
  };
}
EOF
          ;;
        *)
          echo "Error: Unknown category '$category'"
          exit 1
          ;;
      esac
      echo "Created new config for $module_name: $enable_path = $enable_value"
      exit 0
    fi

    # Config exists - modify only the enable flag while preserving everything else
    # This is a simple sed-based approach that looks for the enable line and replaces it

    # Convert enable_path to sed pattern (e.g., "system.audio.enable" -> "enable =")
    enable_line_pattern="enable ="

    # Backup original file
    cp "$config_file" "$config_file.backup.$(date +%s)"

    # Replace the enable line (handles both true/false and preserves formatting)
    if [ "$enable_value" = "true" ] || [ "$enable_value" = "false" ]; then
      # Use sed to replace "enable = true;" or "enable = false;" with new value
      sed -i "s/enable = true;/enable = $enable_value;/g; s/enable = false;/enable = $enable_value;/g" "$config_file"
    fi

    echo "Updated $module_name config: $enable_path = $enable_value"
  '';

in {
  # Export utility functions
  inherit allModules updateModuleConfig;

  # Helper: Get current enable/disable status of a module
  getModuleStatus = moduleName: let
    module = lib.findFirst (m: m.name == moduleName) null allModules;
    configFile = if module != null then module.configFile else "/dev/null";
    enablePath = if module != null then module.enablePath else "enable";
    defaultEnabled = if module != null then module.defaultEnabled else false;
  in ''
    if [ -f "${configFile}" ]; then
      ${pkgs.nix}/bin/nix-instantiate --eval --strict -E \
        "(import ${configFile}).${enablePath} or ${if defaultEnabled then "true" else "false"}" 2>/dev/null || echo "${if defaultEnabled then "true" else "false"}"
    else
      echo "${if defaultEnabled then "true" else "false"}"
    fi
  '';

  enableModule = moduleName: ''
    ${updateModuleConfig}/bin/update-module-config "${moduleName}" "true"
  '';

  disableModule = moduleName: ''
    ${updateModuleConfig}/bin/update-module-config "${moduleName}" "false"
  '';

  # Helper: Format modules for display (used by fzf)
  formatModuleList = ''
    ${lib.concatMapStringsSep "\n" (module: ''
      printf "%-30s %s\\n" "${module.name}" "${module.description}"
    '') allModules}
  '';
}
