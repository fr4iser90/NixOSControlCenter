{ config, pkgs, lib, systemConfig, ... }:

let
  containerManager = config.containerManager.containerManager;

  containerManagerConfig = managerName: {
    userConfig = {
      name = managerName;
      uid = lib.mkForce (if managerName == "docker" then 300 else 200);
      group = lib.mkForce managerName;
      description = "Dedicated user for ${managerName} container management";
      isSystemUser = true;
      linger = true;
      home = "/var/lib/${managerName}";
      createHome = true;
      shell = pkgs.bashInteractive;
      subUidRanges = [ { startUid = 100000; count = 65536; } ];
      subGidRanges = [ { startGid = 100000; count = 65536; } ];

      sessionVariables = {
        DOMAIN = systemConfig.domain;
        EMAIL = systemConfig.email;
        CERT_EMAIL = systemConfig.certEmail;
        TIMEZONE = systemConfig.timeZone;
      };
    };

    socketConfig = {
      description = lib.mkForce "${managerName} API socket";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = "/run/${managerName}/${managerName}.sock";
        SocketMode = "0660";
        SocketUser = lib.mkForce managerName;
        SocketGroup = lib.mkForce managerName;
      };
    };

    serviceConfig = lib.mkIf (managerName == "podman") {
      description = "${managerName} container management";
      requires = [ "${managerName}.socket" ];
      after = [ "${managerName}.socket" ];
      serviceConfig = {
        Type = "notify";
        User = managerName;
        ExecStart = lib.mkForce "${pkgs.podman}/bin/podman system service --time=0 --log-level=debug";
        Restart = "on-failure";
        RestartSec = "5s";
        Delegate = true;
        TimeoutStartSec = "300";
        TimeoutStopSec = "30";
      };
    };
  };

  selectedConfig = containerManagerConfig containerManager;

in {
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

    security = {
      subUidRanges = selectedConfig.userConfig.subUidRanges;
      subGidRanges = selectedConfig.userConfig.subGidRanges;

      # Ensure subuid/subgid ranges are properly configured for the docker user
      subUidOwners = [ { name = containerManager; ranges = selectedConfig.userConfig.subUidRanges; } ];
      subGidOwners = [ { name = containerManager; ranges = selectedConfig.userConfig.subGidRanges; } ];

      wrappers = {
        newuidmap = {
          source = "${pkgs.shadow}/bin/newuidmap";
          setuid = true;
        };
        newgidmap = {
          source = "${pkgs.shadow}/bin/newgidmap";
          setuid = true;
        };
      };
    };

    users = {
      users.${containerManager} = {
        inherit (selectedConfig.userConfig) name uid group description isSystemUser home createHome shell;
      };
      groups.${containerManager} = {
        gid = lib.mkOverride 50 989; # High priority override to preserve existing GID
      };
    };

    system.activationScripts.container-setup = ''
      mkdir -p ${selectedConfig.userConfig.home}
      chown ${containerManager}:${containerManager} ${selectedConfig.userConfig.home}
      chmod 755 ${selectedConfig.userConfig.home}
    '';

    virtualisation.docker.enable = true;
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };

  };
}
