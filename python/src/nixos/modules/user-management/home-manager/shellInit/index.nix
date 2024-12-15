#/etc/nixos/modules/homemanager/shellInit/index.nix
{ pkgs, lib, defaultShell, systemConfig, ... }:

let
  shellInitFile = ./${systemConfig.defaultShell} + "Init.nix";
in
{
  programs = import shellInitFile { inherit pkgs lib; };
}
