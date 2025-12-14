{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.features.specialized.hackathon = {
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

    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;  # Disabled by default (WIP)
      description = ''
        Enable hackathon manager (WIP - Work in Progress).
        
        ⚠️ WARNING: This feature is currently under development and may not be fully functional.
        Use at your own risk.
      '';
    };
  };
}

