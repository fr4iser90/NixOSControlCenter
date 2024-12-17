{ config, lib, pkgs, systemConfig, ... }:

{
  imports = 
    if (systemConfig.sshManager or false)
    then [ ./ssh-manager.nix ]
    else [];
}