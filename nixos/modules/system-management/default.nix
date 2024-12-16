# modules/system-management/default.nix
{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    # Preflight System
    ./preflight
    
    # Hier können später weitere System-Management Module kommen
    # ./monitoring
    # ./maintenance
    # ./backup
    # etc.
  ];

  options = {
    system.management = {
      enablePreflight = lib.mkOption {
        type = lib.types.bool;
        default = systemConfig.preflightChecks or false;
        description = ''
          Whether to enable preflight checks before system rebuilds.
          Can be configured via systemConfig.preflightChecks.
        '';
      };
    };
  };

  config = {
    # Basis-Konfiguration für System-Management
    environment.systemPackages = with pkgs; [
      # Basis-Tools für System-Management
      pciutils
      usbutils
      lshw
    ];
  };
}