{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Self-migration: Use getModuleConfig with systemConfig fallback for safety
  cfg = if (builtins.tryEval (getModuleConfig "module-manager")).success
        then getModuleConfig "module-manager"
        else systemConfig.core.management.module-manager or {};
in {
  _module.metadata = {
    role = "internal";
    name = "module-manager";
    description = "Automatic module discovery and configuration management";
    category = "management";
    subcategory = "modules";
    stability = "stable";
  };
  # Module-manager is always active (Core module, no enable option)
  imports = [
    ./options.nix
    ./config.nix
    ./commands.nix  # ✅ Commands in commands.nix per MODULE_TEMPLATE
  ];
}

