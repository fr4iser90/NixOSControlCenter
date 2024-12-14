# modules/profiles/types/hybrid/gaming-workstation.nix
{ config, lib, pkgs, ... }:

{
  # Default Shell setzen
  users.defaultUserShell = lib.mkForce pkgs.zsh;
  
  # Pakete
  environment.systemPackages = with pkgs; [
    # Development
    vscode
    godot_4
    code-cursor
    git
    git-credential-manager

    # Gaming
    lutris
    #wine
    #winetricks
    #wineWowPackages.full
    noisetorch

    # Multimedia & Communication
    firefox
    thunderbird
    vesktop
    vlc
    ffmpeg
    audacity
    jellyfin-media-player
    owncloud-client

    # System Tools
    kitty
    kate
    pavucontrol
  ];

  # Virtualisierung
  virtualisation = {
    libvirtd.enable = true;
    docker.enable = true;
  };
  
    # Shell-Konfiguration mit mkForce um Konflikte zu vermeiden
  programs = {
    steam.enable = lib.mkDefault true;

    zsh = {
      enable = lib.mkForce true;  # Verwende mkForce
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
    };
    fish.enable = lib.mkDefault true;

    git = {
      enable = true;
      config = {
        credential.helper = "manager"; 
      };
    };
  };

}
