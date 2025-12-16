{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.systemConfig.system.boot = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Boot module version";
    };
    # Boot module has no user-configurable options - it uses systemConfig.system.bootloader
    # to dynamically load the appropriate bootloader implementation
  };
}
