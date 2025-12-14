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
    # Management (includes infrastructure as submodules)
    ./management/system-manager
    ./management/module-manager
  ];
}
