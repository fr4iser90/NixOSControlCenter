# modules/profiles/types/desktop/gaming.nix
{ config, lib, pkgs, ... }:

let
  env = import ../../../env.nix;
in {
  config = lib.mkIf (env.systemType == "gaming") {
    # Gaming-spezifische Konfiguration
    programs.steam.enable = env.overrides.enableSteam or false;
    programs.gamemode.enable = env.overrides.enableGameMode or false;
    # ... weitere Gaming-Einstellungen
  };
}