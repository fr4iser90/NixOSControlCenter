# modules/profiles/types/hybrid/gaming-workstation.nix
{ config, lib, pkgs, systemConfig, ... }:

{

  
  # Pakete
  environment.systemPackages = with pkgs; [
    vscode
    godot_4
    code-cursor
    git
    git-credential-manager
    fzf
    noisetorch
    firefox
    thunderbird
    vesktop
    vlc
    ffmpeg
    audacity
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
