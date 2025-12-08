{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    # Core modules
    ./boot
    ./hardware
    ./network
    ./localization
    ./user
    ./desktop
    ./audio
    # Infrastructure
    ./cli-formatter 
    ./command-center
    ./system-manager
  ];
}