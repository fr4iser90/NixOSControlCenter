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
    ./audio
    ./packages
  ];
}
