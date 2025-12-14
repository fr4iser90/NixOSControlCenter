{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./options.nix
    ./config.nix
  ];
}
