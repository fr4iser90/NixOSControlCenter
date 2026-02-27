# modules/desktop/themes/color-schemes/default.nix
{ config, lib, pkgs, systemConfig, ... }:
let
  desktopCfg = lib.attrByPath ["core" "base" "desktop"] {} systemConfig;
  themeModule = ./schemes + "/${desktopCfg.environment or "plasma"}.nix";
in {
  imports = lib.optionals (desktopCfg.enable or true) [
    themeModule
  ];

  assertions = lib.optionals (desktopCfg.enable or true) [{
    assertion = builtins.pathExists themeModule;
    message = "Color scheme for desktop environment ${desktopCfg.environment} not found";
  }];
}