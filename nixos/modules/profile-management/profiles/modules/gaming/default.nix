{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Gaming Basics
    gamescope
    mangohud
    gamemode
    # Communication
    vesktop
    noisetorch
    # Multimedia
    firefox
    thunderbird
    vlc
    ffmpeg
    audacity
    jellyfin-media-player
    owncloud-client
    # KDE
    kdePackages.kdeconnect-kde
  ];

  programs.steam.enable = true;
}