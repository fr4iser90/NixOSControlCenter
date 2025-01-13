#/etc/nixos/modules/homemanager/shellInit/index.nix
{ pkgs, lib, user, systemConfig, ... }:

let
  shellInitFile = ./${systemConfig.users.${user}.defaultShell} + "Init.nix";
in
{
  programs = import shellInitFile { inherit pkgs lib; };
}
