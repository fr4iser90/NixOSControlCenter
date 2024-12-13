# modules/desktop/display/wayland/extensions.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    plasma-workspace  # KDE Plasma Wayland integration
    wl-clipboard     # Wayland clipboard utilities
    kanshi          # Wayland output management
  ];
}