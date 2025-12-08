# modules/networking/default.nix
{ config, lib, pkgs, systemConfig, ... }:

let  
  # Import sub-modules based on configuration
  networkingModules = [
#    ./networkmanager.nix
#    ./firewall.nix
  ];
in {
  imports = networkingModules;

  # Basic networking configuration
  networking = {
    hostName = systemConfig.hostName;
    
    # Enable NetworkManager by default
    networkmanager.enable = true;

    # Basic firewall settings
    firewall = {
      enable = systemConfig.enableFirewall or false;
      allowPing = true;
    };
  };

  # Time zone configuration
  time.timeZone = systemConfig.timeZone;

  # Assertions for validation
  assertions = [
    {
      assertion = systemConfig.timeZone != "";
      message = "Time zone must be specified in systemConfig";
    }
    {
      assertion = systemConfig.hostName != "";
      message = "Hostname must be specified in systemConfig";
    }
  ];
}