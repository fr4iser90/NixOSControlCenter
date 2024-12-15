{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  types = import ./types;

  profileModule = 
    if types.systemTypes.hybrid ? ${systemConfig.systemType} then
      ./hybrid/gaming-workstation.nix
    else if types.systemTypes.desktop ? ${systemConfig.systemType} then
      ./desktop/${systemConfig.systemType}.nix
    else if types.systemTypes.server ? ${systemConfig.systemType} then
      ./server/${systemConfig.systemType}.nix
    else
      throw "Unknown system type: ${systemConfig.systemType}";

in {
  imports = [
    profileModule
  ];

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "de_DE.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];
  };
}