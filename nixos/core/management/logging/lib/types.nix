{ lib }:

let
  # Report level type
  reportLevelType = lib.types.enum ["basic" "info" "debug" "trace"];

  # Collector configuration type
  collectorConfigType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable this collector";
      };

      detailLevel = lib.mkOption {
        type = lib.types.nullOr reportLevelType;
        default = null;
        description = "Override detail level for this collector";
      };

      priority = lib.mkOption {
        type = lib.types.int;
        default = 100;
        description = "Execution priority (lower = sooner)";
      };
    };
  };

  # Logging configuration type
  loggingConfigType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable system logging";
      };

      defaultDetailLevel = lib.mkOption {
        type = reportLevelType;
        default = "info";
        description = "Default detail level for all reports";
      };

      collectors = lib.mkOption {
        type = lib.types.attrsOf collectorConfigType;
        default = {};
        description = "Collector-specific configurations";
      };
    };
  };

in {
  inherit reportLevelType collectorConfigType loggingConfigType;
}
