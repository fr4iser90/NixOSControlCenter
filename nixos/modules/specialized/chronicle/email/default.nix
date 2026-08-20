{ lib, pkgs, cfg, getModuleApi }:

# Email Module
{ smtp = import ./smtp.nix { inherit lib pkgs cfg getModuleApi; }; }
