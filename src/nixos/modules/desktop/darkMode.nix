{ config, pkgs, lib, ... }:
let
  env = import ../../env.nix;
in
{
  config = lib.mkIf env.darkMode {
    services.displayManager.sddm.theme = "breeze-dark";
    environment.variables.KDE_GLOBAL_THEME = "Breeze Dark";
  };
}
