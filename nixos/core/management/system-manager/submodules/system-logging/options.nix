{ lib, getCurrentModuleMetadata, ... }:

let
  # Finde eigenes Modul aus PFAD! KEIN hardcoded Name!
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
  configPath = metadata.configPath or "systemConfig.core.management.system-manager.submodules.system-logging";  # Fallback
  apiPath = metadata.apiPath or "core.management.system-manager.submodules.system-logging";  # Fallback

  # API Definition - outsourced in api.nix
  apiValue = import ./api.nix { inherit lib; };

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

  options.${configPath} = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "Module version";
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
}
