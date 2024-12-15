# modules/desktop/managers/desktop/gnome.nix
{ config, pkgs, systemConfig, ... }: {
  services.xserver.desktopManager.gnome.enable = true;
}