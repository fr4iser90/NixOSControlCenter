# Slim emulation core. Extra consoles → userPackages or a future optional set.
{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    retroarch
  ];
}
