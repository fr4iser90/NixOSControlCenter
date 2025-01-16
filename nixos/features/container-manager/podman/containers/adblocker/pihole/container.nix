{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.pihole;
in {
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    containerManager.containers.pihole = {
      image = "pihole/pihole:${cfg.imageTag}";
      
      environment = {
        WEBPASSWORD = cfg.webPassword;
        TZ = config.time.timeZone;
        VIRTUAL_HOST = "${cfg.subdomain}.${cfg.domain}";
        DNS1 = elemAt cfg.dns 0;
        DNS2 = elemAt cfg.dns 1;
        PIHOLE_UID = "999";
        PIHOLE_GID = "1000";
        DNSMASQ_USER = "pihole";
      };

      ports = [
        "8053:53/tcp"
        "8053:53/udp"
        "8080:80/tcp"
      ];

      volumes = [
        "/var/lib/podman/.local/share/containers/pihole/etc-pihole:/etc/pihole"
        "/var/lib/podman/.local/share/containers/pihole/etc-dnsmasq.d:/etc/dnsmasq.d"
        "/var/lib/podman/.local/share/containers/pihole/log:/var/log"
        "/run/pihole:/run/pihole"
      ];

      resourceLimits = {
        cpu = cfg.resourceLimits.cpu;
        memory = cfg.resourceLimits.memory;
        swap = cfg.resourceLimits.swap;
      };

      healthCheck = {
        test = [ "CMD" "curl" "-f" "http://localhost/admin/" ];
        interval = "30s";
        timeout = "10s";
        retries = 3;
      };

      restartPolicy = "unless-stopped";
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/podman/.local/share/containers/pihole 0755 999 1000 -"
      "d /var/lib/podman/.local/share/containers/pihole/etc-pihole 0755 999 1000 -"
      "d /var/lib/podman/.local/share/containers/pihole/etc-dnsmasq.d 0755 999 1000 -"
      "d /var/lib/podman/.local/share/containers/pihole/log 0755 999 1000 -"
      "d /run/pihole 0755 999 1000 -"
    ];

    users.users.pihole = {
      isSystemUser = true;
      uid = 999;
      group = "pihole";
      createHome = false;
      shell = pkgs.shadow;
    };

    users.groups.pihole = {
      gid = 1000;
    };

    boot.kernel.sysctl = {
      "net.ipv4.ip_unprivileged_port_start" = 53;
      "kernel.unprivileged_userns_clone" = 1;
    };
  };
}
