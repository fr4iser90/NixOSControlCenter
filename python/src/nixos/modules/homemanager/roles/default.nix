{ config, lib, pkgs, ... }:

{
  imports = [
    ./admin.nix
    ./guest.nix
    ./restricted-admin.nix
  ];
}