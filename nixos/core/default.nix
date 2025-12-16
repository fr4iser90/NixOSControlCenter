{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    # Core system modules
    ./base/boot
    ./base/hardware
    ./base/network
    ./base/localization
    ./base/user
    ./base/desktop
    ./base/audio
    ./base/packages
    # Management (includes infrastructure as submodules)
    ./management/system-manager
    ./management/module-manager
  ];
}
