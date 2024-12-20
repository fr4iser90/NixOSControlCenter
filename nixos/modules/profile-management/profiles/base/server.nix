{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # CLI Essentials
    coreutils
    curl
    wget
    git
    vim
    htop
    tmux
    tree
    fzf
    iotop
    iftop
    ufw
    nmap
  ];
  services.openssh.enable = true;

}