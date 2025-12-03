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

{ config, lib, pkgs, ... }:
{
  # Root Docker aktivieren
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    # Disable deprecated enableNvidia (use hardware.nvidia-container-toolkit.enable instead)
    enableNvidia = false;
    # Optional: Automatisches Cleanup von alten Containern/Images
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # NVIDIA Container Toolkit (replaces deprecated virtualisation.docker.enableNvidia)
  # Only enable if NVIDIA is actually configured (not for AMD/Intel/Radeon)
  hardware.nvidia-container-toolkit.enable = lib.mkIf (
    (config.hardware.nvidia.package or null) != null
  ) true;

  # Docker Pakete installieren
  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    docker-client
  ];
}