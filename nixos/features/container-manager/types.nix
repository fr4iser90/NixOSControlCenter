{ lib, ... }:

with lib;

{
  options.types = {
    containerOptions = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "Enable this container";
          image = mkOption {
            type = types.str;
            description = "Container image to use";
          };
          version = mkOption {
            type = types.str;
            default = "latest";
            description = "Container image version";
          };
          user = mkOption {
            type = types.str;
            description = "User to run container as";
          };
          networks = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Networks to connect to";
          };
          volumes = mkOption {
            type = types.attrsOf types.path;
            default = {};
            description = "Volume mappings";
          };
          environment = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "Environment variables";
          };
          environmentFiles = mkOption {
            type = types.listOf types.path;
            default = [];
            description = "Environment files to include";
          };
          extraOptions = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Additional container options";
          };
          labels = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "Container labels";
          };
          healthcheck = mkOption {
            type = types.nullOr (types.submodule {
              options = {
                command = mkOption {
                  type = types.str;
                  description = "Healthcheck command";
                };
                interval = mkOption {
                  type = types.str;
                  default = "30s";
                };
                timeout = mkOption {
                  type = types.str;
                  default = "5s";
                };
                retries = mkOption {
                  type = types.int;
                  default = 3;
                };
                startPeriod = mkOption {
                  type = types.str;
                  default = "0s";
                  description = "Start period before health checks begin";
                };
              };
            });
            default = null;
          };
          dependsOn = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Container dependencies";
          };
        };
      };
      default = {};
      description = "Container base configuration type";
    };

    securityTypes = mkOption {
      type = types.submodule {
        options = {
          userOptions = mkOption {
            type = types.submodule {
              options = {
                uid = mkOption {
                  type = types.int;
                  description = "User ID";
                };
                group = mkOption {
                  type = types.str;
                  description = "Group";
                };
                groups = mkOption {
                  type = types.listOf types.str;
                  default = [];
                  description = "Additional groups";
                };
                createSystemUser = mkOption {
                  type = types.bool;
                  default = true;
                  description = "Create system user";
                };
              };
            };
            default = {};
            description = "User options type";
          };
          
          secretOptions = mkOption {
            type = types.submodule {
              options = {
                source = mkOption {
                  type = types.path;
                  description = "Secret source";
                };
                owner = mkOption {
                  type = types.str;
                  description = "Secret owner";
                };
                group = mkOption {
                  type = types.str;
                  description = "Secret group";
                };
                mode = mkOption {
                  type = types.str;
                  default = "0400";
                  description = "Secret permissions";
                };
                mountPath = mkOption {
                  type = types.str;
                  description = "Container mount path";
                };
              };
            };
            default = {};
            description = "Secret options type";
          };
        };
      };
      default = {};
      description = "Security types definition";
    };

    networkTypes = mkOption {
      type = types.submodule {
        options = {
          networks = mkOption {
            type = types.attrsOf (types.submodule {
              options = {
                subnet = mkOption {
                  type = types.str;
                  description = "Network subnet";
                };
                gateway = mkOption {
                  type = types.str;
                  description = "Network gateway";
                };
                internal = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Internal only";
                };
              };
            });
            default = {};
            description = "Container networks configuration";
          };
        };
      };
      default = {};
      description = "Network types definition";
    };

    monitoringTypes = mkOption {
      type = types.submodule {
        options = {
          healthcheckOptions = mkOption {
            type = types.submodule {
              options = {
                enable = mkEnableOption "Enable health checking for this container";
                interval = mkOption {
                  type = types.str;
                  default = "30s";
                  description = "Health check interval";
                };
                command = mkOption {
                  type = types.str;
                  description = "Health check command";
                };
                retries = mkOption {
                  type = types.int;
                  default = 3;
                  description = "Number of retries before marking unhealthy";
                };
              };
            };
            default = {};
            description = "Healthcheck options type";
          };
          
          loggingOptions = mkOption {
            type = types.submodule {
              options = {
                enable = mkEnableOption "Enable logging for this container";
                retention = mkOption {
                  type = types.str;
                  default = "7d";
                  description = "Log retention period";
                };
                maxSize = mkOption {
                  type = types.str;
                  default = "100m";
                  description = "Maximum log size before rotation";
                };
                level = mkOption {
                  type = types.enum [ "debug" "info" "warn" "error" ];
                  default = "info";
                  description = "Log level";
                };
              };
            };
            default = {};
            description = "Logging options type";
          };
        };
      };
      default = {};
      description = "Monitoring types definition";
    };
    
    volumeOptions = mkOption {
      type = types.submodule {
        options = {
          path = mkOption {
            type = types.path;
            description = "Local path for volume";
          };
          mode = mkOption {
            type = types.str;
            default = "0755";
          };
          user = mkOption {
            type = types.str;
          };
          group = mkOption {
            type = types.str;
            description = "Group ownership of volume";
          };
          backup = mkOption {
            type = types.bool;
            default = false;
          };
          labels = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "Volume labels";
          };
        };
      };
      default = {};
      description = "Volume options type";
    };
  };
}