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
    delta

    # Gaming
    fzf
    #wine
    #winetricks
    #wineWowPackages.full
    noisetorch

    # Multimedia
    firefox
    thunderbird
    vesktop
    vlc
    ffmpeg
    audacity
    jellyfin-media-player
    owncloud-client

    kdePackages.kdeconnect-kde
    
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
