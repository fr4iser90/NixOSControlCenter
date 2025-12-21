# modules/networking/default.nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Import sub-modules based on configuration
  networkingModules = [
    ./options.nix
    ./config.nix
#    ./networkmanager.nix
#    ./firewall.nix
  ];

  networkCfg = getModuleConfig "network";
  localizationCfg = getModuleConfig "localization";

in {
  _module.metadata = {
    role = "internal";
    name = "network";
    description = "Network configuration and management";
    category = "base";
    subcategory = "network";
    stability = "stable";
  };

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