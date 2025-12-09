# docker-rootless.nix
# Rootless Docker Konfiguration für NixOS
#
# WICHTIG: Docker Swarm im Rootless-Modus ist experimentell und hat Einschränkungen.
# Für vollständige Swarm-Funktionalität wird normalerweise root Docker benötigt.
#
# Diese Konfiguration aktiviert rootless Docker systemweit.
# Jeder User kann dann rootless Docker als User-Service starten:
#   systemctl --user enable --now docker
#
# Der Docker Socket ist dann unter $XDG_RUNTIME_DIR/docker.sock verfügbar
# (normalerweise /run/user/$UID/docker.sock).
#
# Verwendung:
# - Normal: docker ps, docker run, etc. funktionieren wie gewohnt
# - Swarm: docker swarm init (experimentell, kann Probleme haben)
#
# Für Swarm später: Wechsle zu docker.nix (root Docker)

{ config, lib, pkgs, ... }:
{
  # Rootless Docker aktivieren
  # WICHTIG: virtualisation.docker.enable sollte NICHT gesetzt sein!
  # Nur rootless.enable aktivieren für rootless Docker
  virtualisation.docker.rootless = {
    enable = true;
    # Setzt DOCKER_HOST automatisch für alle User
    setSocketVariable = true;
  };

  # DOCKER_HOST deklarativ für alle User setzen
  # Jeder User bekommt automatisch DOCKER_HOST gesetzt
  environment.sessionVariables = {
    DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/docker.sock";
  };

  # Optional: Docker Daemon Settings (funktionieren auch im rootless Modus)
  # Diese werden über die rootless Docker Konfiguration angewendet
  # virtualisation.docker.daemon.settings = {
  #   dns = [ "1.1.1.1" "8.8.8.8" ];
  #   log-driver = "journald";
  #   storage-driver = "overlay2";
  # };

  # Docker Pakete installieren
  # Für rootless Docker wird das normale docker-Paket verwendet
  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    docker-client
  ];
}
