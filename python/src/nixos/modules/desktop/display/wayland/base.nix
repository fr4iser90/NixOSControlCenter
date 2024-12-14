# modules/desktop/display/wayland/base.nix
{ config, pkgs, ... }: {
  programs.xwayland.enable = true;

  environment.systemPackages = with pkgs; [
    wayland-protocols
    wayland-utils
    kdePackages.kwayland   
    kdePackages.plasma-workspace   
    kdePackages.kwin   
  ];
  security.pam.services.sddm.enableKwallet = true;
}