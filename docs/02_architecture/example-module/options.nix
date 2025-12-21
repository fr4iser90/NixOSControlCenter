{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.modules.example-module = {
    # Version metadata (REQUIRED for all modules)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Module version";
    };

    enable = lib.mkEnableOption "example module";

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

