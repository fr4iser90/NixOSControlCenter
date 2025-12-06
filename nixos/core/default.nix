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
    # Infrastructure
    ./cli-formatter 
    ./command-center
    ./system-manager
  ];
}