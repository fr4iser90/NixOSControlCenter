{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

with lib;

let
  cfg = getModuleConfig "hackathon";
  
  # Finde alle Benutzer mit hackathon-admin Rolle
  hackathonUsers = lib.filterAttrs 
    (name: user: user.role == "hackathon-admin") 
    systemConfig.core.base.user;

  # Prüfe ob wir Hackathon-Admin-Benutzer haben
  hasHackathonUsers = (lib.length (lib.attrNames hackathonUsers)) > 0;

  # Hole den ersten Hackathon-Admin-Benutzer, falls vorhanden
  hackathonUser = if hasHackathonUsers then lib.head (lib.attrNames hackathonUsers) else "";

in {
  _module.metadata = {
    role = "optional";
    name = "hackathon";
    description = "Hackathon environment management";
    category = "specialized";
    subcategory = "development";
    stability = "experimental";
  };

  imports = if cfg.enable or false then [
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
      modules.specialized.hackathon.enable = mkDefault (cfg.enable or false);
    }
    (mkIf cfg.enable {
      # Feature-specific config here
    })
  ];
}
