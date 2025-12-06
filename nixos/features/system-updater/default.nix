{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.features.system-updater;
in {
  imports = [
    ./options.nix
    ./update.nix
    ./feature-manager.nix
    ./homelab-utils.nix
    ./channel-manager.nix
  ];

  config = mkMerge [
    {
      features.system-updater.enable = mkDefault (systemConfig.features.system-updater or false);
    }
    (mkIf cfg.enable {
      # Feature-specific config here
    })
  ];
}