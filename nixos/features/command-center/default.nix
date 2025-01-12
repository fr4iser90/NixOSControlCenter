{ config, lib, pkgs, ... }:

{
  imports = [
    ./registry
    ./cli
  ];
}