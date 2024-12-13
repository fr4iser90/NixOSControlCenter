# src/nixos/modules/nix/default.nix
{ config, lib, pkgs, ... }: {
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
    };
    
  };
}