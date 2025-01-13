{ config, lib, pkgs, ... }:

{
  imports = [
    ./adblocker/pihole/pihole.nix
  ];
}