# modules/networking/default.nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Single Source: Modulname nur einmal definieren
  moduleName = baseNameOf ./. ;  # ← network aus core/base/network/

  # Import sub-modules based on configuration
  networkingModules = [
    ./options.nix
    (import ./config.nix { inherit config lib pkgs getModuleConfig moduleName; })
#    ./networkmanager.nix
#    ./firewall.nix
  ];

  networkCfg = getModuleConfig moduleName;
  localizationCfg = getModuleConfig "localization";  # Anderes Modul, bleibt hardcoded

in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Network configuration and management";
    category = "base";
    subcategory = "network";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

  imports = networkingModules;

  # Basic networking configuration
  networking = {
    hostName = networkCfg.hostName or "nixos";

    # Enable NetworkManager by default
    networkmanager.enable = true;

    # Basic firewall settings
    firewall = {
      enable = networkCfg.firewall.enable or false;
      allowPing = true;
    };
  };

  # Time zone configuration
  time.timeZone = localizationCfg.timeZone or "Europe/Berlin";

  # Assertions for validation
  assertions = [
    {
      assertion = localizationCfg.timeZone != "";
      message = "Time zone must be specified in localization config";
    }
    {
      assertion = networkCfg.hostName != "";
      message = "Hostname must be specified in network config";
    }
  ];
}