# modules/desktop/themes/index.nix
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  cfg = getModuleConfig "desktop";
in {
  imports = lib.optionals (cfg.enable or true) [
    ./color-schemes
    ./cursors
    ./fonts
    ./icons
  ];
}