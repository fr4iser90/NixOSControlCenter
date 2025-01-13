{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./gpu
    ./cpu
    ./memory
  ];

}