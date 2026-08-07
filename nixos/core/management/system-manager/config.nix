{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:
let
  cfg = getModuleConfig "system-manager";
in
{
  config = lib.mkMerge [
    # Component commands are registered from commands.nix / handlers
  ];
}
