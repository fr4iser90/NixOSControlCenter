# modules/desktop/display/wayland/tools.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    waybar          # Wayland status bar
    wofi            # Wayland application launcher
  ];
}