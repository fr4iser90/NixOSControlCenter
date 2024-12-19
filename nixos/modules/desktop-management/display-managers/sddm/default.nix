# src/nixos/modules/desktop-management/display-managers/sddm/default.nix
{ config, pkgs, systemConfig, ... }: {
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