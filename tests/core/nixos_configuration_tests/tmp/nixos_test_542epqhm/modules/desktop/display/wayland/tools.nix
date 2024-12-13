# modules/desktop/display/wayland/tools.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    weston          # Reference Wayland compositor
    sway            # Tiling Wayland compositor
    waybar          # Wayland status bar
    wofi            # Wayland application launcher
  ];
}