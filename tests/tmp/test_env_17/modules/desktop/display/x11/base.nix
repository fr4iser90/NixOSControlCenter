# modules/desktop/display/x11/base.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    xorg.xorgserver  # X.Org server
    xorg.xhost       # X server access control
    xorg.xinit       # X initialization
    xorg.xauth       # X authentication
  ];
}