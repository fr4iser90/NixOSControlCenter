{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  # Define the user for the Pihole container
  piholeUser = "pihole";
  piholeGroup = "pihole";
  # Default variables fallback
  defaultVars = {
    PIHOLE_UID = "999";
    PIHOLE_GID = "1000";
    DNSMASQ_USER = "pihole";
  };
  cfg = config.services.pihole;
  containerVars = import ./vars.nix { inherit lib config; };
  mergedVars = containerVars // defaultVars;
  validatedVars = config.validateVars config.containerManager.vars { };
in {
  options.services.pihole = {
    enable = mkEnableOption "Enable Pi-hole DNS service";
  };

  config = {

    # Fix permissions for volumes
    systemd.tmpfiles.rules = [
      "d /var/lib/containers/pihole 0755 999 1000 -"
      "d /var/lib/containers/pihole/etc-pihole 0755 999 1000 -"
      "d /var/lib/containers/pihole/etc-dnsmasq.d 0755 999 1000 -"
      "d /var/lib/containers/pihole/log 0755 999 1000 -"
      "d /run/pihole 0755 999 1000 -"
    ];
    
    virtualisation.oci-containers.containers.pihole = {
      image = "pihole/pihole:${cfg.imageTag}";
      user = "${mergedVars.PIHOLE_UID}:${mergedVars.PIHOLE_GID}";
      autoStart = false;
      ports = [
        "8053:53/tcp"  # DNS TCP von Port 53 auf 8053 umleiten
        "8053:53/udp"  # DNS UDP von Port 53 auf 8053 umleiten
        "8080:80"        # Bind to unprivileged port for the web interface
      ];
      volumes = [
        "/var/lib/containers/pihole/etc-pihole:/etc/pihole"
        "/var/lib/containers/pihole/etc-dnsmasq.d:/etc/dnsmasq.d"
        "/var/lib/containers/pihole/log:/var/log"
        "/run/pihole:/run/pihole"
      ];
      environmentFiles = [
        (pkgs.writeText "pihole-env" (builtins.concatStringsSep "\n" (
          mapAttrsToList (name: value: "${name}=${value}") validatedVars
        )))
      ];
      environment = {
        PIHOLE_UID = mergedVars.PIHOLE_UID;
        PIHOLE_GID = mergedVars.PIHOLE_GID;
        DNSMASQ_USER = mergedVars.DNSMASQ_USER;
      };
      extraOptions = [
#        "--cap-add=NET_BIND_SERVICE"
#        "--cap-add=CAP_SETGID"
#        "--cap-add=CAP_SETUID"
        "--network=proxy"
        "--label=traefik.enable=true"
        "--label=traefik.docker.network=proxy"
        "--label=traefik.http.routers.pihole.entrypoints=websecure"
        "--label=traefik.http.routers.pihole.rule=Host(`${cfg.subdomain}.${cfg.domain}`)"
        "--label=traefik.http.routers.pihole.tls=true"
        "--label=traefik.http.routers.pihole-secure.service=pihole"
        "--label=traefik.http.routers.pihole.tls.certresolver=http_resolver"
        "--label=traefik.http.routers.pihole.middlewares=default@file,admin-whitelist@file,rate-limit@docker"
        "--label=traefik.http.services.pihole.loadbalancer.server.port=80"
      ];  
    };

    # Ensure the pihole user and group are created on the host
    users.users.${piholeUser} = {
      isSystemUser = true;
      uid = 999;  # Set your preferred UID here
      group = piholeGroup;
      createHome = false;
      shell = pkgs.shadow; 
    };

    users.groups.${piholeGroup} = {
      gid = 1000;  # Set your preferred GID here
    };
  boot.kernel.sysctl = {
    "net.ipv4.ip_unprivileged_port_start" = 53;
    "kernel.unprivileged_userns_clone" = 1; # for plex
  };
  };
}
