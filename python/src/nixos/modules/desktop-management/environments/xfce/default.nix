# modules/desktop/managers/desktop/xfce.nix
{ config, pkgs, systemConfig, ... }: {
  services.xserver.desktopManager.xfce.enable = true;
}
