# gaming.nix
# Gaming Launcher und Kommunikation
# Enthält: Steam, Epic Games, GOG, Discord (vesktop) und weitere Gaming-Tools

{ config, lib, pkgs, ... }:
{
  # Steam aktivieren
  programs.steam = {
    enable = true;
    # Remote Play Together aktivieren (optional)
    remotePlay.openFirewall = true;
    # Dedicated Server aktivieren (optional)
    dedicatedServer.openFirewall = true;
  };

  # Gaming Launcher und Tools
  environment.systemPackages = with pkgs; [
    # Kommunikation
    vesktop              # Discord Client (privacy-freundlich)
    
    # Gaming Launcher
    heroic              # Epic Games & GOG Launcher (universell)
    lutris              # Gaming Launcher (unterstützt viele Stores)
    # legendary          # Epic Games CLI (optional, falls CLI bevorzugt wird)
    
    # Gaming Tools
    mangohud            # Performance Overlay für Games
    goverlay            # GUI für MangoHUD und andere Overlays
    # wine               # Wird normalerweise von Lutris/Steam mitgebracht
    # winetricks         # Wine Utilities
  ];
}