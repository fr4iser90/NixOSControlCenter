#/etc/nixos/modules/homemanager/shellInit/index.nix
{ pkgs, lib, user, systemConfig, ... }:

let
  shellInitFile = ./${systemConfig.core.base.user.${user}.defaultShell} + "Init.nix";
in
{
  programs = import shellInitFile { inherit pkgs lib; };
}
