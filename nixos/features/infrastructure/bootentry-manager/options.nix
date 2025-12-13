{ lib, ... }:

let
  moduleVersion = "1.0";
  types = import ./lib/types.nix { inherit lib; };
in {
  options.features.infrastructure.bootentry = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Feature version";
    };

    # Dependencies this module has
    _dependencies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "system-checks" "command-center" ];
      internal = true;
      description = "Modules this feature depends on";
    };

    # Conflicts this module has
    _conflicts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      internal = true;
      description = "Modules that conflict with this feature";
    };

    enable = lib.mkEnableOption "boot entry manager";
    
    description = lib.mkOption {
      type = types.str;
      default = "Boot entry management for various bootloaders";
      description = "Feature description";
    };
  };
}

