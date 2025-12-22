#/etc/nixos/modules/homemanager/shellInit/index.nix
{ pkgs, lib, user, systemConfig, getModuleConfig, ... }:

let
  userCfg = getModuleConfig "user";
  shellInitFile = ./${userCfg.${user}.defaultShell} + "Init.nix";
in
{
  programs = import shellInitFile { inherit pkgs lib; };
}
