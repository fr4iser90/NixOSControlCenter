{ config, lib, pkgs, ... }:

with lib;

{
  options = {
    container = {
      enable = mkEnableOption "Enable container";
    
      name = mkOption {
        type = types.str;
        description = "Container name";
      };

      image = mkOption {
        type = types.str;
        description = "Container image name";
      };

      version = mkOption {
        type = types.str;
        default = "latest";
        description = "Container image version";
      };

      command = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Container command override";
      };

      entrypoint = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Container entrypoint override";
      };

      env = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Environment variables";
      };

      network = {
        ports = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Port mappings";
        };
        
        type = mkOption {
          type = types.enum [ "bridge" "host" "slirp4netns" ];
          default = "bridge";
          description = "Network type";
        };
        
        dns = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Custom DNS servers";
        };
      };

      volumes = mkOption {
        type = types.listOf (types.submodule {
          options = {
            source = mkOption {
              type = types.path;
              description = "Host path";
            };
            target = mkOption {
              type = types.str;
              description = "Container path";
            };
            readOnly = mkOption {
              type = types.bool;
              default = false;
              description = "Mount as read-only";
            };
          };
        });
        default = [];
        description = "Volume mounts";
      };

      security = {
        capabilities = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Linux capabilities";
        };
        
        privileged = mkOption {
          type = types.bool;
          default = false;
          description = "Run in privileged mode";
        };
      };

      logging = {
        driver = mkOption {
          type = types.enum [ "journald" "json-file" "syslog" ];
          default = "journald";
          description = "Logging driver";
        };
        
        maxSize = mkOption {
          type = types.str;
          default = "10m";
          description = "Maximum log file size";
        };
        
        maxFiles = mkOption {
          type = types.int;
          default = 3;
          description = "Maximum number of log files";
        };
      };

      resources = {
        cpu = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "CPU shares";
        };
        
        memory = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Memory limit";
        };
        
        swap = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Swap limit";
        };
      };

      healthcheck = {
        command = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Health check command";
        };
        
        interval = mkOption {
          type = types.str;
          default = "30s";
          description = "Health check interval";
        };
        
        timeout = mkOption {
          type = types.str;
          default = "5s";
          description = "Health check timeout";
        };
        
        retries = mkOption {
          type = types.int;
          default = 3;
          description = "Health check retries";
        };
        
        startPeriod = mkOption {
          type = types.str;
          default = "30s";
          description = "Initial health check delay";
        };
      };

      restartPolicy = mkOption {
        type = types.enum [ "no" "on-failure" "always" "unless-stopped" ];
        default = "no";
        description = "Container restart policy";
      };

      dependsOn = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Dependent containers";
      };
    };
  };

  config = {
    systemd.services = mapAttrs (name: container: {
      description = "Container ${name}";
      after = [ "network.target" ] ++ map (dep: "container-${dep}.service") container.dependsOn;
      requires = map (dep: "container-${dep}.service") container.dependsOn;
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
            ++ concatMap (dns: [ "--dns" dns ]) container.network.dns
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
  };
}
