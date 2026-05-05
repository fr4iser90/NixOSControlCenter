# modules/networking/default.nix
{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

   let
     # Single Source: Modulname nur einmal definieren
     moduleName = baseNameOf ./. ;  # ← network aus core/base/network/

     # Import sub-modules based on configuration
     networkingModules = [
       ./options.nix
       (import ./config.nix { inherit config lib pkgs getModuleConfig moduleName; })
       ./handlers/networkmanager.nix
       ./handlers/firewall.nix
     ];

     networkCfg = getModuleConfig moduleName;
     # LOOSE DEPENDENCY: Localization config mit Fallback wenn nicht vorhanden
     localizationCfg = getModuleConfig "localization" // { timeZone = "Europe/Berlin"; };

in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Network configuration and management";
    category = "base";
    subcategory = "network";
    version = "1.0.0";
  };

  imports = networkingModules ++ [ (import ./commands.nix { inherit config lib pkgs getModuleApi moduleName systemConfig; }) ];

  # Basic networking configuration
  networking = {
    hostName = networkCfg.hostName;

    # Enable NetworkManager by default
    networkmanager.enable = true;

    # Firewall configuration is handled in handlers/firewall.nix
    # to avoid conflicts and ensure proper enable/disable handling
  };

   # Time zone configuration mit Fallback
   time.timeZone = if localizationCfg.timeZone != "" then localizationCfg.timeZone else "Europe/Berlin";

   # Assertions for validation
   assertions = [
     {
       assertion = networkCfg.hostName != "";
       message = "Hostname must be specified in network config";
     }
   ];
}