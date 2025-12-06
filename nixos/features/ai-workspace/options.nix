{ lib, ... }:

let
  featureVersion = "1.0";
in {
  options.features.ai-workspace = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = featureVersion;
      internal = true;
      description = "Feature version";
    };

    enable = lib.mkEnableOption "AI workspace";
  };
}

