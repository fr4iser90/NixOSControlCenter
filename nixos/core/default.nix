{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    # Core system modules
    ./system/boot
    ./system/hardware
    ./system/network
    ./system/localization
    ./system/user
    ./system/desktop
    ./system/audio
    ./system/packages
    # Infrastructure
    ./infrastructure/cli-formatter 
    ./infrastructure/command-center
    ./infrastructure/config
    # Management
    ./management/system-manager
    ./management/module-manager
    ./management/checks
    ./management/logging
  ];
}
