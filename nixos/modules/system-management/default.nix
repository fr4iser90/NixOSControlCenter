# modules/system-management/default.nix
{ config, lib, pkgs, ... }:

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
        default = true;
        description = ''
          Whether to enable preflight checks before system rebuilds.
          Set to false to skip all preflight checks.
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