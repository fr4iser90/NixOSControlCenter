# modules/profiles/types/desktop/gaming.nix
{ config, lib, pkgs, systemConfig, ... }:
{
  config = lib.mkIf (systemConfig.systemType == "gaming") {
    # Gaming-spezifische Konfiguration
    programs.steam.enable = systemConfig.overrides.enableSteam or false;
    programs.gamemode.enable = systemConfig.overrides.enableGameMode or false;
    # ... weitere Gaming-Einstellungen
  };
}