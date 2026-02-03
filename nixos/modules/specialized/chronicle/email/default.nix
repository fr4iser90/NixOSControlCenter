{ lib, pkgs, cfg }:

# Email Module
{ smtp = import ./smtp.nix { inherit lib pkgs cfg; }; }
