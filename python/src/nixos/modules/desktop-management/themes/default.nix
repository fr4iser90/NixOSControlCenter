# modules/desktop/themes/index.nix
{ config, lib, pkgs, ... }:

let
  env = import ../../../env.nix;
in {
  imports = [
#    ./color-schemes
#    ./cursors
#    ./fonts
#    ./icons
  ];
}