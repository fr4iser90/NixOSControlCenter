{ lib, getCurrentModuleMetadata, ... }:

let
  moduleVersion = "1.0";
  # Get module metadata to determine configPath dynamically (generic, not hardcoded)
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  # Options must be under systemConfig prefix with dynamic configPath
  options.systemConfig.${configPath} = {
    # Version metadata (REQUIRED for all modules)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Module version";
    };

    # Enable option for optional modules
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable example module";
    };

    # Example options
    option1 = lib.mkOption {
      type = lib.types.str;
      default = "default-value";
      description = "Example option 1";
    };

    option2 = lib.mkOption {
      type = lib.types.int;
      default = 42;
      description = "Example option 2";
    };

    nested = {
      option = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Nested option example";
      };
    };
  };
}

