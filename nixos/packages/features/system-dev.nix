# System Development default
{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    cmake
    ninja
    gcc
    clang
  ];
}