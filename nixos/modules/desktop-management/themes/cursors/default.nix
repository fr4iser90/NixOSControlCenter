# modules/desktop/themes/cursors/index.nix
{ config, lib, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    vanilla-dmz         # Basic cursor theme
    capitaine-cursors   # Modern cursor theme
  ];
}