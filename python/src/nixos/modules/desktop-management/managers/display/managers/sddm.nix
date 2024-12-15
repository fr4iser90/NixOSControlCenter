# modules/desktop/managers/display/sddm.nix
{ config, pkgs, env, ... }: {
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };  

  security.pam.services.sddm = {
    enableKwallet = false;
    startSession = true;
    setEnvironment = true;
  };
}
