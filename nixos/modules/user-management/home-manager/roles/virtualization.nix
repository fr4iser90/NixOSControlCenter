{ config, lib, pkgs, user, systemConfig, ... }:

let
  userConfig = systemConfig.users.${user};
  shellInit = import ../shellInit/${userConfig.defaultShell}Init.nix { inherit pkgs lib; };
in {
  imports = [ shellInit ];

  home = {
    stateVersion = "24.05";
    username = user;
    homeDirectory = "/home/${user}";
  };

  # Virtualisierungs-spezifische Konfiguration
  home.packages = with pkgs; [
    docker-compose
    virt-manager
    qemu
  ];

  # Gruppen für Virtualisierung
  users.users.${user}.extraGroups = [
    "docker"
    "libvirtd"
    "kvm"
  ];

  # Environment-Variablen für Docker
  home.sessionVariables = {
    EMAIL = "${systemConfig.email}";
    DOMAIN = "${systemConfig.domain}";
    CERTEMAIL = "${systemConfig.certEmail}";
    DOCKER_CONFIG = "$HOME/.docker";
    DOCKER_BUILDKIT = "1";
  };
}