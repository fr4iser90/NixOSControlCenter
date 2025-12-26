{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./base
    ./management
  ];
}
