# src/nixos/modules/desktop-management/display-managers/gdm/default.nix
{ config, pkgs, systemConfig, ... }: {
  services.xserver.displayManager.gdm.enable = true;
}
