{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.core.management.module-manager = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Module manager version";
    };
    # NOTE: No enable option - module-manager is always active (Core module)

    enabledModulesMap = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = {};
      description = "Map of enabled modules";
    };

    moduleConfigMap = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Module configuration map";
    };
  };
}
