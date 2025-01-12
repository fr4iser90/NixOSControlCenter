{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    retroarch
    dolphin-emu
    pcsx2
    rpcs3
    cemu
  ];
}