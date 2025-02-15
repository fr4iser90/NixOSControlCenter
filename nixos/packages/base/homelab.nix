{ config, lib, pkgs, systemConfig, ... }:

{
  # Basis-Konfiguration für Homelab
  services.openssh.enable = true;
  virtualisation.docker.enable = true;
  # Firefox nur aktivieren, wenn Desktop aktiviert ist
  programs.firefox.enable = systemConfig.desktop.enable or false;

  # Verhindern, dass der PC in den Ruhemodus geht
  services.logind.extraConfig = ''
    HandleLidSwitch=ignore
    IdleAction=ignore
  '';
  
  environment.systemPackages = with pkgs; [
    # CLI Essentials
    coreutils
    curl
    docker 
    docker-client
    wget
    git
    neovim
    htop
    tmux
    tree
    fzf
    iotop
    iftop
    nmap
    gnupg
  ];


}
