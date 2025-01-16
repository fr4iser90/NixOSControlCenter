{ config, lib, pkgs, ... }:

{
  imports = [
    ./container.nix
    ./options.nix
    ./volumes.nix
    ./vars.nix
  ];
}
