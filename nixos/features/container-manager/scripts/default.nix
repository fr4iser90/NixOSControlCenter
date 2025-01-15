{ config, lib, pkgs, systemConfig, ... }:
{
  imports = [
    ./networking.nix
    ./storage.nix
    ./security.nix
    ./monitoring.nix
    ./types.nix
    ./scripts
  ];
}
