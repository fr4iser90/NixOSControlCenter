# modules/desktop/managers/desktop/default.nix
{ config, lib, pkgs, ... }:

let
  env = import ../../../../env.nix;
  
  # Definiere gültige Desktop-Environments als Set
  validDesktops = {
    plasma = true;
    gnome = true;
    xfce = true;
  };

  # Import specific desktop environment configuration
  desktopConfig = import ./${env.desktop}.nix {
    inherit config pkgs;
  };
in {
  imports = [ desktopConfig ];

  assertions = [
    {
      assertion = builtins.hasAttr env.desktop validDesktops;
      message = "Invalid desktop environment: ${env.desktop}";
    }
  ];
}