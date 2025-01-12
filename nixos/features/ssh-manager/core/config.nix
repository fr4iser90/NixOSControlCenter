{ config, lib, pkgs, ... }:
{
  config = {
    environment.systemPackages = [ 
      pkgs.fzf
      pkgs.openssh
    ];
  };
}

