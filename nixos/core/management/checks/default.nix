{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.management.checks or {};
in {
  imports = [
    ./options.nix
    ./prebuild
    ./postbuild
  ];

  config = mkMerge [
    {
      systemConfig.management.checks.enable = mkDefault (systemConfig.management.checks.enable or false);
    }
    (mkIf cfg.enable {
      environment.systemPackages = with pkgs; [
        pciutils
        usbutils
        lshw
      ];
    })
  ];
}