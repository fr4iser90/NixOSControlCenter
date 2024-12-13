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

  systemInfo = {
    hasDesktop = env.desktop != null && env.desktop != "";
  };

in {
  imports = [
    profileModule
  ] ++ (optionals systemInfo.hasDesktop [
    ../desktop 
    ../sound
  ]);
}