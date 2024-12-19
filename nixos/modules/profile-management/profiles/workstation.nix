# modules/profiles/types/hybrid/workstation.nix
{ config, lib, pkgs, systemConfig, ... }:
{
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
    jellyfin-media-player
    owncloud-client
    kitty
    kate
    pavucontrol
    tree
    delta
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
