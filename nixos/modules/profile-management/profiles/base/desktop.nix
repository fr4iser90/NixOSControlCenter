{ config, lib, pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    coreutils
    curl
    wget
    git
    vim
    htop
    tmux
  ];
}