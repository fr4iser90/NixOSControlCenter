{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    # Core modules
    ./boot
    ./hardware
    ./network
    ./system
    ./user
    ./desktop
    ./audio
    # Infrastructure
    ./cli-formatter 
    ./command-center
    ./system-manager
  ];
}