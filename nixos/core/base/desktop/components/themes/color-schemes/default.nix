# modules/desktop/themes/color-schemes/default.nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  cfg = getModuleConfig "desktop";
  themeModule = ./schemes + "/${cfg.environment or "plasma"}.nix";
in {
  imports = lib.optionals (cfg.enable or true) [
    themeModule
  ];

  assertions = lib.optionals (cfg.enable or true) [{
    assertion = builtins.pathExists themeModule;
    message = "Color scheme for desktop environment ${cfg.environment} not found";
  }];
}