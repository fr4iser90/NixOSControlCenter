# modules/desktop/managers/desktop/plasma.nix
{ config, pkgs, ... }: {
  services.xserver.desktopManager.plasma5.enable = true;
}