{ lib, ... }:

let
  moduleVersion = "1.0";
  name="NCC Module Manager";
in {
  options.systemConfig.core.management.module-manager = {
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

    configHelpers = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Configuration helpers provided by the module manager";
      internal = true;
    };
  };

  # Config namespace for module manager API
  options.core.management.module-manager = {
    configHelpers = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Configuration helpers provided by the module manager";
      internal = true;
    };
  };

  # Define _module.metadata as a valid option for all modules
  options._module.metadata = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Module metadata for discovery and management";
    internal = true;
  };
}
