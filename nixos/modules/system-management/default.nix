# modules/system-management/default.nix
{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    # Preflight System
    ./preflight
    ./update

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