{ config, lib, pkgs, ... }:

{
  imports = [
    ./vector
    ./postgres
  ];
}