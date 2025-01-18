{ config, lib, pkgs, ... }:

{
  imports = [
    ./selection.nix
    ./base.nix
    ./networks.nix
    ./volumes.nix
    ./security-options.nix
  ];
}
