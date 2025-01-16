{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.containerManager;
in {
  imports = [ 
    ./modules/container-options.nix
    ./modules/container-implementation.nix
    ./containers
  ];

  options.containerManager = {
    enable = mkEnableOption "Rootless Podman container management";

    logging = {
      driver = mkOption {
        type = types.enum [ "journald" "json-file" "syslog" ];
        default = "journald";
        description = "Default logging driver for containers";
      };
    };

    user = mkOption {
      type = types.str;
      default = "podman";
      description = "User for rootless container management";
    };

    containers = mkOption {
      type = types.attrsOf (types.submodule {
        options = {};
      });
      default = {};
      description = "Container configurations";
    };

    network = {
      enable = mkEnableOption "Enable container networking";
      bridgeName = mkOption {
        type = types.str;
        default = "podman0";
        description = "Bridge interface name";
      };
      subnet = mkOption {
        type = types.str;
        default = "10.88.0.0/16";
        description = "Container network subnet";
      };
    };

    defaultLogging = {
      driver = mkOption {
        type = types.enum [ "journald" "json-file" "syslog" ];
        default = "journald";
        description = "Default logging driver for containers";
      };
      maxSize = mkOption {
        type = types.str;
        default = "10m";
        description = "Default maximum log file size";
      };
      maxFiles = mkOption {
        type = types.int;
        default = 3;
        description = "Default maximum number of log files";
      };
    };

    defaultResources = {
      cpu = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Default CPU shares for containers";
      };
      memory = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Default memory limit for containers";
      };
      swap = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Default swap limit for containers";
      };
    };
  };

  config = {
    environment.systemPackages = with pkgs; [
      podman
      slirp4netns
      fuse-overlayfs
      crun
      shadow
      conmon
      iptables
    ];

    virtualisation.podman = {
      enable = true;
      dockerCompat = false;
      autoPrune.enable = true;
      defaultNetwork.settings = {
        network_name = cfg.network.bridgeName;
        subnet = cfg.network.subnet;
      };
    };

    users.users.podman = {
      isSystemUser = true;
      subUidRanges = [ { startUid = 100000; count = 65536; } ];
      subGidRanges = [ { startGid = 100000; count = 65536; } ];
      home = "/var/lib/podman";
      group = "podman";
      createHome = true;
      shell = pkgs.bashInteractive;
    };

    system.activationScripts.podman-setup = let
      podmanDataDir = "/var/lib/podman/.local/share/containers";
    in ''
      mkdir -p ${podmanDataDir}
      chown -R podman:podman ${podmanDataDir}
      chmod 755 ${podmanDataDir}
    '';

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
        ExecStart = "${pkgs.podman}/bin/podman system service --time=0 --log-level=debug";
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = "300";
        TimeoutStopSec = "30";
        Environment = [
          "PODMAN_DEBUG=1"
          "PODMAN_SERVICE_LOG=${cfg.logging.driver}"
        ];
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    users.groups.podman = {};
  };
}
