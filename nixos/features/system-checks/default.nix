{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.features.system-checks;
in {
  imports = [
    ./options.nix
    ./prebuild
    ./postbuild
  ];

  config = mkMerge [
    {
      features.system-checks.enable = mkDefault (systemConfig.features.system-checks or false);
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