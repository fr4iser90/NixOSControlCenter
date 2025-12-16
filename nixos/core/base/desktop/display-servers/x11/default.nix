# modules/desktop/display/x11/index.nix
{ config, pkgs, ... }: {
  imports = [
    ./base.nix
    ./extensions.nix
  ];
}