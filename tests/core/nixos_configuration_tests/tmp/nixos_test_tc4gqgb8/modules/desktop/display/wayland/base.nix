# modules/desktop/display/wayland/base.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    wayland-protocols  # Core Wayland protocols
    wayland-utils     # Basic Wayland utilities
    xwayland         # X11 compatibility layer
  ];
}