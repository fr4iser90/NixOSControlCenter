{ config, lib, pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    coreutils
    curl
    wget
    git
    neovim
    htop
    docker
    tmux
    tree
    fzf
    bottles-unwrapped
  ];
}