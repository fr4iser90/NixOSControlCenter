{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./android.nix
    ./ios.nix
  ];
}
