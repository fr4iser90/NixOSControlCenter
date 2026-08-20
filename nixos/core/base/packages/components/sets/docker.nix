# docker.nix
# Root Docker Konfiguration für NixOS
#
# Diese Konfiguration aktiviert Docker mit Root-Rechten.
# WICHTIG: Mitglieder der docker-Gruppe haben effektiv Root-Rechte!
#
# Verwendung:
# - Normal: docker ps, docker run, etc. funktionieren wie gewohnt
# - Swarm: docker swarm init (vollständig unterstützt)
#
# Für mehr Sicherheit: Verwende docker-rootless.nix (aber Swarm ist dann experimentell)

{ config, lib, pkgs, getModuleConfig, ... }:
with lib;
let
  # Jetson/Jetpack still keys CTK off enableNvidia; desktop uses nvidia-container-toolkit alone.
  isJetson = ((getModuleConfig "hardware").gpu or "") == "jetson";
in
{
  # Root Docker aktivieren
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    # Desktop: force off deprecated flag. Jetson: keep on for jetpack CTK defaults.
    enableNvidia = if isJetson then true else mkForce false;
    # Optional: Automatisches Cleanup von alten Containern/Images
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Docker Pakete installieren
  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    docker-client
  ];
}