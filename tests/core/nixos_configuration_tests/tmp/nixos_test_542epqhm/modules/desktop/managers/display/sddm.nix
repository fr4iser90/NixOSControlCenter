
# modules/desktop/managers/display/sddm.nix
{ config, pkgs, env, ... }: {
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
}