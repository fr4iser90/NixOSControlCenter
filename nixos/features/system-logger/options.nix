{ lib, ... }:

let
  featureVersion = "1.0";
  
  # Report Level Definition
  reportLevels = {
    minimal = 1;
    standard = 2;
    detailed = 3;
    full = 4;
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
  options.features.system-logger = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = featureVersion;
      internal = true;
      description = "Feature version";
    };

    enable = lib.mkEnableOption "system logger";
    
    defaultDetailLevel = lib.mkOption {
      type = lib.types.enum (lib.attrNames reportLevels);
      default = "standard";
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
}

