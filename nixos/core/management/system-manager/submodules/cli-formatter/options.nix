{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  # User configuration (accessed via systemConfig.core.management.system-manager.submodules.cli-formatter)
  options.systemConfig.core.management.system-manager.submodules.cli-formatter = {
    # Version metadata (REQUIRED for all modules)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "CLI formatter module version";
    };

    enable = lib.mkEnableOption "CLI formatter";

    config = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "CLI formatter configuration options";
    };

    components = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "Enable this component";

          refreshInterval = lib.mkOption {
            type = lib.types.int;
            default = 5;
            description = "Refresh interval in seconds";
          };

          template = lib.mkOption {
            type = lib.types.lines;
            description = "Component template using CLI formatter API";
          };
        };
      });
      default = {};
      description = "Custom CLI formatter components";
    };
  };

  # API definition (accessed via config.core.management.system-manager.submodules.cli-formatter)
  options.core.management.system-manager.submodules.cli-formatter = {
    api = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = "CLI formatter API for other features (read-only)";
    };
  };
}
