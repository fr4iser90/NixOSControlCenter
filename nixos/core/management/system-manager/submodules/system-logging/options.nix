{ lib, ... }:

let
  moduleVersion = "1.0";
  
  # Report Level Definition
  reportLevels = {
    basic = 1;
    info = 2;
    debug = 3;
    trace = 4;
  };

  # Collector-spezifische Optionen
  mkCollectorOptions = name: {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the ${name} collector";
    };

    detailLevel = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum (lib.attrNames reportLevels));
      default = null;
      description = "Override detail level for ${name} collector";
    };

    priority = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "Execution priority for ${name} collector";
    };
  };

  # Verfügbare Collectors
  availableCollectors = [
    "profile"
    "bootloader"
    "bootentries"
    "packages"
  ];
in {
  options.systemConfig.core.management.system-manager.submodules.system-logging = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Feature version";
    };

    enable = lib.mkEnableOption "system logger";
    
    defaultDetailLevel = lib.mkOption {
      type = lib.types.enum (lib.attrNames reportLevels);
      default = "info";
      description = "Default detail level for all reports";
    };

    collectors = lib.mkOption {
      type = lib.types.submodule {
        options = lib.listToAttrs (map (name: {
          name = name;
          value = lib.mkOption {
            type = lib.types.submodule {
              options = mkCollectorOptions name;
            };
            default = {};
            description = "Configuration for the ${name} collector";
          };
        }) availableCollectors);
      };
      default = {};
      description = "Collector-specific configurations";
    };
  };

  # NixOS Module Options (for config.core namespace)
  options.core.management.system-manager.submodules.system-logging = {
    # System Logger - Core module always available
    system-logger = {
      defaultDetailLevel = lib.mkOption {
        type = lib.types.enum (lib.attrNames reportLevels);
        default = "info";
        description = "Default detail level for system logging";
      };

      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable system logging";
      };
    };
  };
}
