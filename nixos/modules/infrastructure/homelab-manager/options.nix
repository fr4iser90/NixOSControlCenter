{ lib, ... }:

{
  options.modules.infrastructure.homelab = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "Module version";
    };

    # Dependencies this module has (modular approach)
    _dependencies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "system-checks" "command-center" ];  # Needs these core modules
      internal = true;
      description = "Modules this module depends on";
    };

    # Conflicts this module has (modular approach)
    _conflicts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];  # Modules that conflict with this one
      internal = true;
      description = "Modules that conflict with this module";
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
