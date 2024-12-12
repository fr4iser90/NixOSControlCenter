# modules/desktop/managers/desktop/gnome.nix
{ config, pkgs, ... }: {
  services.xserver.desktopManager.gnome.enable = true;
}