# modules/desktop/managers/display/gdm.nix
{ config, pkgs, env, ... }: {
  services.xserver.displayManager.gdm.enable = true;
}
