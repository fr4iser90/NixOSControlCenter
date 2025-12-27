{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./system-manager
    ./module-manager
    ./nixos-control-center 
    ./cli-registry
    ./cli-formatter   
    ./tui-engine
  ];
}
