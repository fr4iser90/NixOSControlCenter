{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.systemConfig.core.system.packages = {
    # Version metadata (REQUIRED)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Packages module version";
    };

    # Package modules list (V1 format)
    packageModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of package modules to enable (docker, docker-rootless, gaming, etc.)";
    };

    # Preset configuration
    preset = {
      modules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Modules from preset configuration";
      };
    };

    # Docker configuration
    docker = {
      enable = lib.mkEnableOption "Docker support";
      root = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Force root Docker (auto-detected for Swarm/AI-Workspace)";
      };
    };
  };
}

