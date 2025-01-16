{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.container;
in {
  config = {
    virtualisation.podman = {
      enable = true;
      dockerCompat = mkDefault true;
      defaultNetwork.settings.dns_enabled = true;
      extraPackages = [ pkgs.crun ];
    };

    systemd.services = mapAttrs (name: container: {
      description = "Container ${name}";
      after = [ "network.target" "podman.service" ] ++ map (dep: "container-${dep}.service") container.dependsOn;
      requires = [ "podman.service" ] ++ map (dep: "container-${dep}.service") container.dependsOn;
      path = [ pkgs.podman ];
      serviceConfig = {
        ExecStart = let
          logging = container.logging // {
            driver = container.logging.driver or "journald";
            maxSize = container.logging.maxSize or "10m";
            maxFiles = container.logging.maxFiles or 3;
          };
          
          resources = container.resources // {
            cpu = container.resources.cpu or null;
            memory = container.resources.memory or null;
            swap = container.resources.swap or null;
          };
          
          args = [
            "run"
            "--name=${name}"
            "--rm"
            "--network=${container.network.type}"
            "--log-driver=${logging.driver}"
            "--log-opt=max-size=${logging.maxSize}"
            "--log-opt=max-file=${toString logging.maxFiles}"
          ] ++ optionals (container.command != null) [ "--entrypoint=${escapeShellArgs container.command}" ]
            ++ optionals (container.entrypoint != null) [ "--entrypoint=${escapeShellArgs container.entrypoint}" ]
            ++ concatMap (port: [ "-p" port ]) container.network.ports
            ++ concatMap (volume: [ "-v" "${volume.source}:${volume.target}:${if volume.readOnly then "ro" else "rw"}" ]) container.volumes
            ++ optionals container.security.privileged [ "--privileged" ]
            ++ optionals (resources.cpu != null) [ "--cpus=${toString resources.cpu}" ]
            ++ optionals (resources.memory != null) [ "--memory=${resources.memory}" ]
            ++ optionals (resources.swap != null) [ "--memory-swap=${resources.swap}" ]
            ++ concatMap (cap: [ "--cap-add" cap ]) container.security.capabilities
            ++ optionals (container.healthcheck.command != null) [
              "--health-cmd=${container.healthcheck.command}"
              "--health-interval=${container.healthcheck.interval}"
              "--health-timeout=${container.healthcheck.timeout}"
              "--health-retries=${toString container.healthcheck.retries}"
              "--health-start-period=${container.healthcheck.startPeriod}"
            ];
        in "${pkgs.podman}/bin/podman ${escapeShellArgs args} ${container.image}:${container.version}";
        
        ExecStop = "${pkgs.podman}/bin/podman stop -t 10 ${name}";
        ExecStopPost = "${pkgs.podman}/bin/podman rm -f ${name}";
        Restart = container.restartPolicy;
        RestartSec = "5s";
        TimeoutStopSec = "30s";
        Type = "notify";
        NotifyAccess = "all";
        User = "podman";
      };
      environment = container.env;
    }) cfg.containers;


    users.groups.podman = {};
    users.users.podman = {
      isSystemUser = true;
      subUidRanges = [ { startUid = 100000; count = 65536; } ];
      subGidRanges = [ { startGid = 100000; count = 65536; } ];
      home = "/var/lib/podman";
      group = "podman";
      createHome = true;
      shell = mkForce pkgs.bashInteractive;
    };
    users.users.root.extraGroups = [ "podman" ];
  };
}
