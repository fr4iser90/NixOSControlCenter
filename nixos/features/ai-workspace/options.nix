{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.features.ai-workspace = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Feature version";
    };

    enable = lib.mkEnableOption "AI workspace";
  };
}

