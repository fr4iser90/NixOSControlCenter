# modules/desktop/display/wayland/extensions.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    plasma-workspace  # KDE Plasma Wayland integration
    libsForQt5.plasma-workspace
    wl-clipboard     # Wayland clipboard utilities
    kanshi          # Wayland output management
  ];
}