{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Gaming Basics
    gamescope
    mangohud
    gamemode
    lutris
    wine
    bottles-unwrapped
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
  ];

  programs.steam.enable = true;

    # Noisetorch Capabilities hinzufügen
  security.wrappers.noisetorch = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_resource+ep";
    source = "${pkgs.noisetorch}/bin/noisetorch";
  };
}