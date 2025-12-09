{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.features.infrastructure.homelab = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Feature version";
    };

    enable = lib.mkEnableOption "homelab manager";

    # Basic configuration options
    swarm = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "manager" "worker" ]);
      default = null;
      description = "Docker Swarm mode: null for single-server, manager or worker for swarm";
    };

    stacks = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [];
      description = "List of Docker stack configurations";
      example = [
        {
          name = "my-stack";
          compose = "/path/to/docker-compose.yml";
          env = "/path/to/.env";
        }
      ];
    };
  };
}
