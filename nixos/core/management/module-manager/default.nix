{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Self-migration: Use getModuleConfig with systemConfig fallback for safety
  cfg = getModuleConfig "module-manager";
in {
  _module.metadata = {
    role = "core";
    name = "module-manager";
    description = "Automatic module discovery and configuration management";
    category = "management";
    subcategory = "modules";
    version = "1.0.0";
  };
  # Module-manager is always active (Core module, no enable option)
  imports = [
    ./options.nix
    ./config.nix
    ./commands.nix  # ✅ Commands in commands.nix per MODULE_TEMPLATE
  ];
}

