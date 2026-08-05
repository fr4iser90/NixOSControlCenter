# modules/desktop/display/x11/base.nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    xorgserver  # X.Org server
    xhost       # X server access control
    xinit       # X initialization
    xauth       # X authentication
  ];
}