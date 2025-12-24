{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Single Source: Modulname nur einmal definieren
  moduleName = "module-manager";
  # Self-migration: Use getModuleConfig with systemConfig fallback for safety
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Automatic module discovery and configuration management";
    category = "management";
    subcategory = "modules";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;
  # Module-manager is always active (Core module, no enable option)
  imports = [
    ./options.nix
    ./config.nix
    ./commands.nix  # ✅ Commands in commands.nix per MODULE_TEMPLATE
  ];
}

