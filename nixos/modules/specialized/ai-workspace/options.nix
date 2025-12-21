{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.modules.ai-workspace = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
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

    enable = lib.mkEnableOption "AI workspace";
  };
}

