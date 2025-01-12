{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./prebuild
    ./postbuild
  ];

    environment.systemPackages = with pkgs; [
      pciutils
      usbutils
      lshw
    ];
}