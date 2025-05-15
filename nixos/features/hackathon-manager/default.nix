{ config, lib, pkgs, systemConfig, ... }:

let
  # Finde alle Benutzer mit hackathon-admin Rolle
  hackathonUsers = lib.filterAttrs 
    (name: user: user.role == "hackathon-admin") 
    systemConfig.users;

  # Prüfe ob wir Hackathon-Admin-Benutzer haben
  hasHackathonUsers = (lib.length (lib.attrNames hackathonUsers)) > 0;

  # Hole den ersten Hackathon-Admin-Benutzer, falls vorhanden
  hackathonUser = if hasHackathonUsers then lib.head (lib.attrNames hackathonUsers) else "";

in {
  imports = if hasHackathonUsers then [
    ./hackathon-fetch.nix
    ./hackathon-create.nix
    ./hackathon-update.nix
    ./hackathon-status.nix
    ./hackathon-cleanup.nix
  ] else [];

  # Aktiviere Container-Manager, wenn Hackathon-Manager aktiviert ist
  config = lib.mkIf hasHackathonUsers {
    containerManager.containerManager = "docker";
    containerManager.networks = {
      hackathon = {
        subnet = "172.60.0.0/16";
        gateway = "172.60.0.1";
      };
    };
    
    # Stelle sicher, dass die notwendigen Pakete installiert sind
    environment.systemPackages = with pkgs; [
      docker-compose
      git
      jq
      curl
    ];
    
    # Firewall-Konfiguration für Hackathon-Plattform
    networking.firewall = {
      allowedTCPPorts = [ 80 443 8080 ];
      allowedUDPPorts = [ 53 ];
    };
  };
}
