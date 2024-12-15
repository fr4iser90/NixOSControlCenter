# modules/desktop/display/wayland/index.nix
{ config, pkgs, ... }: {
  imports = [
    ./base.nix
    ./extensions.nix
  ];
}