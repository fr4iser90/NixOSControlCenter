# modules/desktop/display/wayland/extensions.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    #waybar          # Wayland status bar
    #wofi            # Wayland application launcher
  ];
}