{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./keyboard.nix
    ./language.nix
  ];
}