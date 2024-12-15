{ config, lib, pkgs, ... }:

with lib;

let
  env = import ../../env.nix;
  types = import ./types;

  profileModule = 
    if types.systemTypes.hybrid ? ${env.systemType} then
      ./hybrid/gaming-workstation.nix
    else if types.systemTypes.desktop ? ${env.systemType} then
      ./desktop/${env.systemType}.nix
    else if types.systemTypes.server ? ${env.systemType} then
      ./server/${env.systemType}.nix
    else
      throw "Unknown system type: ${env.systemType}";

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