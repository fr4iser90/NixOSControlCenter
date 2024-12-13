# modules/desktop/display/wayland/index.nix
{ config, pkgs, ... }: {
  imports = [
    ./base.nix
    ./tools.nix
    ./extensions.nix
  ];
}