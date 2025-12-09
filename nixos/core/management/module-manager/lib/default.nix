{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  ui = config.core.cli-formatter.api;
  hostname = systemConfig.hostName;

  # 🎯 GENERIC: Discover all available modules from systemConfig API
  # Instead of hardcoded list - dynamic discovery from current configuration!

  # System modules - all available in systemConfig.system.*
  systemModules = lib.mapAttrsToList (name: value:
    {
      name = "system.${name}";
      enablePath = "systemConfig.system.${name}.enable";
      configFile = "/etc/nixos/configs/${name}-config.nix";
      category = "system";
      description = "${name} system configuration";
      defaultEnabled = true;  # System modules are usually enabled
    }
  ) (systemConfig.system or {});

  # Management modules - all available in systemConfig.management.*
  managementModules = lib.mapAttrsToList (name: value:
    {
      name = "management.${name}";
      enablePath = "systemConfig.management.${name}.enable";
      configFile = "/etc/nixos/configs/${name}-config.nix";
      category = "management";
      description = "${name} management tools";
      defaultEnabled = true;  # Management modules are usually enabled
    }
  ) (systemConfig.management or {});

  # Features - all available in systemConfig.features.*
  # Features have nested structure: features.category.module
  featureModules = lib.flatten (
    lib.mapAttrsToList (categoryName: categoryValue:
      if builtins.isAttrs categoryValue then
        lib.mapAttrsToList (moduleName: moduleValue:
          {
            name = "features.${categoryName}.${moduleName}";
            enablePath = "systemConfig.features.${categoryName}.${moduleName}.enable";
            configFile = "/etc/nixos/configs/${moduleName}-config.nix";
            category = "features";
            description = "${moduleName} feature (${categoryName})";
            defaultEnabled = false;  # Features are disabled by default
          }
        ) categoryValue
      else []
    ) (systemConfig.features or {})
  );

  # 🎯 COMBINE all modules dynamically
  allModules = systemModules ++ managementModules ++ featureModules;

in {
  # Export all utility functions
  inherit systemModules managementModules featureModules allModules;

  # Helper: Get current enable/disable status of a module
  getModuleStatus = moduleName: let
    module = lib.findFirst (m: m.name == moduleName) null allModules;
  in ''
    if [ -n "${toString module}" ] && [ -f "${module.configFile}" ]; then
      ${pkgs.nix}/bin/nix-instantiate --eval --strict -E \
        "(import ${module.configFile}).${module.enablePath} or ${if module.defaultEnabled then "true" else "false"}" 2>/dev/null || echo "${if module.defaultEnabled then "true" else "false"}"
    else
      echo "${if module.defaultEnabled then "true" else "false"}"
    fi
  '';

  # Helper: Generate config file for a module
  updateModuleConfig = pkgs.writeShellScriptBin "update-module-config" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    module_name="$1"
    value="$2"

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

    # Generate config based on category
    case "$category" in
      "system")
        module_short=$(basename "$config_file" "-config.nix")
        cat > "$config_file" <<EOF
{
  $module_short = {
    enable = $value;
  };
}
EOF
        ;;
      "management")
        module_short=$(basename "$config_file" "-config.nix")
        cat > "$config_file" <<EOF
{
  $module_short = {
    enable = $value;
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
        enable = $value;
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
  '';

  # Format all available modules for fzf
  formatModuleList = pkgs.writeScript "format-modules" ''
    #!${pkgs.bash}/bin/bash
    ${lib.concatMapStringsSep "\n" (module: ''
      status=$(${getModuleStatus "${module.name}"})
      printf "%-35s %-10s %s\n" "${module.name}" "[$status]" "${module.description}"
    '') allModules}
  '';

  enableModule = moduleName: ''
    ${updateModuleConfig}/bin/update-module-config "${moduleName}" "true"
  '';

  disableModule = moduleName: ''
    ${updateModuleConfig}/bin/update-module-config "${moduleName}" "false"
  '';
}
