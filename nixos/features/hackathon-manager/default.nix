{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.features.hackathon-manager;
  
  # Finde alle Benutzer mit hackathon-admin Rolle
  hackathonUsers = lib.filterAttrs 
    (name: user: user.role == "hackathon-admin") 
    systemConfig.users;

  # Prüfe ob wir Hackathon-Admin-Benutzer haben
  hasHackathonUsers = (lib.length (lib.attrNames hackathonUsers)) > 0;

  # Hole den ersten Hackathon-Admin-Benutzer, falls vorhanden
  hackathonUser = if hasHackathonUsers then lib.head (lib.attrNames hackathonUsers) else "";

in {
  imports = [
    ./options.nix
  ] ++ (if hasHackathonUsers then [
    ./hackathon-fetch.nix
    ./hackathon-create.nix
    ./hackathon-update.nix
    ./hackathon-status.nix
    ./hackathon-cleanup.nix
  ] else []);

  config = mkMerge [
    {
      features.hackathon-manager.enable = mkDefault (systemConfig.features.hackathon-manager or false);
    }
    (mkIf cfg.enable {
      # Feature-specific config here
    })
  ];
}
