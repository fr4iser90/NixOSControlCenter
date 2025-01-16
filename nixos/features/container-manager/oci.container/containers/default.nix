{ config, lib, pkgs, ... }:

{
  imports = [
    ./adblocker/pihole
  ];
}