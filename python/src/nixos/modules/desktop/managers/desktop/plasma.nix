# modules/desktop/managers/desktop/plasma.nix
{ config, pkgs, ... }: {
  services.xserver.desktopManager.plasma6.enable = true;
}