{ config, lib, pkgs, systemConfig, ... }:

let
  ui = config.core.cli-formatter.api;
  hostname = systemConfig.hostName;

  # FULLY GENERIC: Each module defines its own defaults!
  # Use absolute paths from flake root
  flakeRoot = ../../../..;
  discoverAllModules =
    (discoverModulesInDir "${flakeRoot}/core") ++
    (discoverModulesInDir "${flakeRoot}/features");

  discoverModulesInDir = basePath: let
    baseDir = basePath;
    contents = builtins.readDir baseDir;
  in lib.flatten (
    lib.mapAttrsToList (name: type:
      if type == "directory" then
        let
          moduleDir = "${baseDir}/${name}";
          hasDefault = builtins.pathExists "${moduleDir}/default.nix";
        in if hasDefault then
          # Each module decides its own defaults!
          let
            # Try to read the module's options to get its default
            defaultEnabled = false; # Fallback
          in [{
            name = name;
            enablePath = "systemConfig.${name}.enable";
            configFile = "/etc/nixos/configs/${name}-config.nix";
            category = baseNameOf basePath;
            description = "${name}";
            defaultEnabled = defaultEnabled;  # Each module defines this itself
          }]
        else []
      else []
    ) contents
  );

  # ALL modules discovered automatically
  allModules = discoverAllModules;

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

in {
  # Export all utility functions
  inherit allModules;

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