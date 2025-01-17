{ config, lib, pkgs, systemConfig, ... }:

{
  # Basis-Konfiguration für Homelab
  services.openssh.enable = true;
  virtualisation.docker.enable = true;

  # Firefox nur aktivieren, wenn Desktop aktiviert ist
  programs.firefox.enable = systemConfig.desktop.enable or false;

  environment.systemPackages = with pkgs; [
    # CLI Essentials
    coreutils
    curl
    wget
    git
    neovim
    htop
    tmux
    tree
    fzf
    iotop
    iftop
    ufw
    nmap
    gnupg
  ];


}