{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./registry
    ./cli
  ];
}