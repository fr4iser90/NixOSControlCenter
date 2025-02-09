{ config, pkgs, lib, systemConfig, ... }:
let
  containerManager = config.containerManager.containerManager;
  isDocker = containerManager == "docker";
  isPodman = containerManager == "podman";
  
  # Gemeinsame Umgebungsvariablen
  commonEnvVariables = {
    DOMAIN = systemConfig.domain;
    EMAIL = systemConfig.email;
    TIMEZONE = systemConfig.timeZone;
    DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/$UID/bus";
  };

in {
  config = lib.mkMerge [
    {
      # Systemweite Umgebungsvariablen
      environment.sessionVariables = commonEnvVariables;

      # Benutzer und Gruppenkonfiguration
      users.users.${containerManager} = {
        isSystemUser = true;
        group = containerManager;
        uid = lib.mkForce (if isDocker then 300 else 200);
        description = "Dedicated user for ${containerManager}";
        linger = true;
        home = "/var/lib/${containerManager}";
        createHome = true;
        shell = pkgs.bashInteractive;
        subUidRanges = [{ startUid = 100000; count = 65536; }];
        subGidRanges = [{ startGid = 100000; count = 65536; }];
      };

      users.groups.${containerManager}.gid = lib.mkOverride 50 989;

      # Sicherheitseinstellungen
      security = {
        subUidOwners = [ containerManager ];
        subGidOwners = [ containerManager ];
        wrappers = {
          newuidmap.source = "${pkgs.shadow}/bin/newuidmap";
          newgidmap.source = "${pkgs.shadow}/bin/newgidmap";
        };
      };

      # Kernel-Einstellungen
      boot.kernel.sysctl = {
        "user.max_user_namespaces" = 15000;
        "net.bridge.bridge-nf-call-iptables" = 1;
        "net.bridge.bridge-nf-call-ip6tables" = 1;
      };

      # Erforderliche Systempakete
      environment.systemPackages = with pkgs; [
        slirp4netns
        fuse-overlayfs
        crun
        shadow
        conmon
        iptables
        dbus
      ] ++ lib.optional isDocker pkgs.docker
        ++ lib.optional isPodman pkgs.podman;
    }

    (lib.mkIf isDocker {
      virtualisation.docker.rootless = {
        enable = true;
        package = pkgs.docker;
        setSocketVariable = true; # Automatisch DOCKER_HOST setzen
      };

      # Umgebungsvariable systemweit setzen
      environment.sessionVariables = {
        DOCKER_HOST = "unix:///run/user/${toString config.users.users.${containerManager}.uid}/docker.sock";
      };

      # Systemd-Autostart für den Benutzerdienst
      systemd.user.services.docker.wantedBy = ["default.target"];
    })

    (lib.mkIf isPodman {
      # Podman-spezifische Konfiguration
      systemd.sockets.podman = {
        description = "Podman API socket";
        wantedBy = [ "sockets.target" ];
        socketConfig = {
          ListenStream = "/run/podman/podman.sock";
          SocketMode = "0660";
          SocketUser = "podman";
          SocketGroup = "podman";
        };
      };

      systemd.services.podman = {
        description = "Podman container management";
        requires = [ "podman.socket" ];
        after = [ "podman.socket" ];
        serviceConfig = {
          Type = "notify";
          User = "podman";
          ExecStart = "${pkgs.podman}/bin/podman system service --time=0";
          Restart = "on-failure";
          RestartSec = "5s";
          Delegate = true;
          TimeoutStartSec = "300";
        };
      };
    })
  ];
}