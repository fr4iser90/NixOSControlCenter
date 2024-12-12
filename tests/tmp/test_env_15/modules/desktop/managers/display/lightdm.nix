# modules/desktop/managers/display/lightdm.nix
{ config, pkgs, env, ... }: {
  services.xserver.displayManager.lightdm.enable = true;
}