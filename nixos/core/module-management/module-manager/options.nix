{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.systemConfig.module-management.module-manager = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Module manager version";
    };

    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable module manager (feature enable/disable, version checking)";
    };
  };
}

