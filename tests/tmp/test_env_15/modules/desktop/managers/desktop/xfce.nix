# modules/desktop/managers/desktop/xfce.nix
{ config, pkgs, ... }: {
  services.xserver.desktopManager.xfce.enable = true;
}