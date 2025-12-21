{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.systemConfig.core.base.boot = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Boot module version";
    };
    # Boot module has no user-configurable options - it uses systemConfig.core.base.bootloader
    # to dynamically load the appropriate bootloader implementation
  };
}
