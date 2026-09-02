# modules/desktop/themes/color-schemes/default.nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  cfg = getModuleConfig "desktop";
  themeModule = ./schemes + "/${cfg.environment or "plasma"}.nix";
  hasColorScheme = builtins.pathExists themeModule;
in {
  # Only import when a per-environment scheme exists (gnome today).
  imports = lib.optionals ((cfg.enable or true) && hasColorScheme) [
    themeModule
  ];
}