# modules/profiles/types/hybrid/gaming-workstation.nix
{ config, lib, pkgs, systemConfig, ... }:
{
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
    fzf
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
    tree
  ];

  
  programs = {
    steam.enable = true;
    git = {
      enable = true;
      config = {
        credential.helper = "manager"; 
      };
    };
  };

}
