# Hyprland session — loaded when desktop.environment = "hyprland"
{ config, lib, pkgs, ... }: {
  programs.hyprland = {
    enable = lib.mkDefault true;
    xwayland.enable = lib.mkDefault true;
  };

  services.displayManager.defaultSession = lib.mkDefault "hyprland";
  programs.xwayland.enable = lib.mkDefault true;
}
