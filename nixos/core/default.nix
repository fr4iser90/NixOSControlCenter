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
    # Infrastructure
    ./infrastructure/cli-formatter 
    ./infrastructure/command-center
    ./infrastructure/config
    # Module Management
    ./module-management/module-manager
    # Management
    ./management/system-manager
    ./management/checks
    ./management/logging
  ];
}