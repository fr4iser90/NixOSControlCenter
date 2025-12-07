{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.features.hackathon-manager = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Feature version";
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

