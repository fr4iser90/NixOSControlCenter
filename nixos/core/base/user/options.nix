{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.systemConfig.core.base.user = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "User module version";
    };
    # User module has no additional options - it uses systemConfig.core.base.user directly
    # User configuration is managed centrally in system-config.nix
  };
}
