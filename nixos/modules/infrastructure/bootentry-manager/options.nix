{ lib, moduleName }:

let
  types = import ./lib/types.nix { inherit lib; };
in {
  options.systemConfig.modules.infrastructure.${moduleName} = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "Module version";
    };

    # Dependencies this module has
    _dependencies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "system-checks" "command-center" ];
      internal = true;
      description = "Modules this module depends on";
    };

    # Conflicts this module has
    _conflicts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      internal = true;
      description = "Modules that conflict with this module";
    };

    enable = lib.mkEnableOption "${moduleName}";
    
    description = lib.mkOption {
      type = types.str;
      default = "Boot entry management for various bootloaders";
      description = "Feature description";
    };
  };
}

