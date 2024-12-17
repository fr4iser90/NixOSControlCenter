{ config, lib, pkgs, systemConfig, ... }:

{
  imports = 
    if (systemConfig.flakeUpdater or false)
    then [ ./flake-updater.nix ]
    else [];
}