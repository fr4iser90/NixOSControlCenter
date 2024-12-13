# modules/desktop/themes/icons/index.nix
{ config, lib, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    papirus-icon-theme
    numix-icon-theme
    numix-icon-theme-circle
  ];
}