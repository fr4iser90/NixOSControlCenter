# src/nixos/modules/desktop-management/display-managers/lightdm/default.nix
{ config, pkgs, systemConfig, ... }: {
  services.xserver.displayManager.lightdm.enable = true;
}