# modules/system-management/default.nix
{ config, lib, pkgs, systemConfig, ... }:

{
  imports = 
    lib.optional (systemConfig.preflightChecks or false) ./preflight
    ++ lib.optional (systemConfig.flakeUpdater or false) ./update;

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
      pciutils
      usbutils
      lshw
    ];
  };
}