# modules/networking/default.nix
{ config, lib, pkgs, ... }:

let
  env = import ../../env.nix;
  
  # Import sub-modules based on configuration
  networkingModules = [
    ./networkmanager.nix
#    ./firewall.nix
    # Conditional imports based on env settings
    #(lib.mkIf env.enableWireless ./wireless.nix)
    #(lib.mkIf env.enableCustomDNS ./dns.nix)
  ];
in {
  imports = networkingModules;

  # Basic networking configuration
  networking = {
    hostName = env.hostName;
    
    # Enable NetworkManager by default
    networkmanager.enable = true;

    # Basic firewall settings
    firewall = {
      enable = env.enableFirewall;
      allowPing = true;
    };
  };

  # Time zone configuration
  time.timeZone = env.timeZone;

  # Assertions for validation
  assertions = [
    {
      assertion = env.timeZone != "";
      message = "Time zone must be specified in env.nix";
    }
    {
      assertion = env.hostName != "";
      message = "Hostname must be specified in env.nix";
    }
  ];
}