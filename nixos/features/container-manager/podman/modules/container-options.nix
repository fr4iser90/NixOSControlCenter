{ config, lib, ... }:

with lib;

{
  imports = [ ./container-implementation.nix ];

  options = {
    container = {
      enable = mkEnableOption "Enable container";
      
      containers = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
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
        });
        default = {};
        description = "Container configurations";
      };
    };
  };
}
