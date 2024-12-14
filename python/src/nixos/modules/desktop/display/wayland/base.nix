# modules/desktop/display/wayland/base.nix
{ config, pkgs, ... }: {
  programs.xwayland.enable = true;
  
  environment.systemPackages = with pkgs; [
    wayland-protocols
    wayland-utils
    libsForQt5.qt5.qtwayland
    plasma5Packages.kwayland
  ];
  security.pam.services.sddm.enableKwallet = true;
}