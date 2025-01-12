{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    # Core modules
    ./boot
    ./hardware
    ./network
    ./system
    ./user
  ];
}