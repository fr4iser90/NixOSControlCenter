# modules/desktop/themes/color-schemes/index.nix
{ config, lib, pkgs, ... }:

let
  env = import ../../../../env.nix;
  
  # Theme configurations for different desktop environments
  themeConfigs = {
    plasma = import ./plasma.nix;
    gnome = import ./gnome.nix;
    xfce = import ./xfce.nix;
  };

  # Select appropriate theme config
  themeConfig = themeConfigs.${env.desktop} or {};
in {
  imports = [ themeConfig ];
}