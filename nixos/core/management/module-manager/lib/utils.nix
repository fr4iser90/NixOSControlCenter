# Module Manager Utility Functions
{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, ... }:

let
  ui = getModuleApi "cli-formatter";
  hostname = lib.attrByPath ["hostName"] "nixos" (getModuleConfig "network");

  # Own discovery — same module, OK
  discovery = import ./discovery.nix { inherit lib; };
  allModules = discovery.discoverAllModules;

  smRoot = (getModuleMetadata "system-manager").path;
  facade = import "${smRoot}/lib/config-facade.nix" { inherit pkgs; };

  # Helper: Generate config file for a module (PRESERVES EXISTING CONFIG!)
  # Layout-aware via generated config-facade (monolith ↔ split)
  updateModuleConfig = pkgs.writeShellScriptBin "update-module-config" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    module_name="$1"
    enable_value="$2"

    ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}

    module_path=""
    ${lib.concatMapStringsSep "\n" (module: ''
      if [ "$module_name" = "${module.name}" ]; then
        module_path="${lib.replaceStrings ["."] ["/"] module.configPath}"
      fi
    '') allModules}

    if [ -z "$module_path" ]; then
      echo "Error: Module '$module_name' not found in available modules"
      exit 1
    fi

    ncc_set_module_enable "$module_path" "$enable_value"
    echo "Updated $module_name enable=$enable_value (layout=$(ncc_detect_layout))"
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

  # Helper: Format modules for display (used by Bubble Tea TUI)
  formatModuleList = ''
    ${lib.concatMapStringsSep "\n" (module: ''
      printf "%-30s %s\\n" "${module.name}" "${module.description}"
    '') allModules}
  '';
}
