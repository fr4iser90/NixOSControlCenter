{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    # Core system modules
    ./boot
    ./hardware
    ./network
    ./localization
    ./user
    ./desktop
    ./hyprland
    ./audio
    ./packages
  ];
}
