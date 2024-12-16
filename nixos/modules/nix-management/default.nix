# src/nixos/modules/nix/default.nix
{ config, lib, pkgs, systemConfig, ... }: {
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
    };
    
  };
}