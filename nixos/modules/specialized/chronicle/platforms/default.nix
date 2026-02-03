{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./windows.nix
    ./macos.nix
  ];
}
