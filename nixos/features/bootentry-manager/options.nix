{ lib, ... }:

let
  featureVersion = "1.0";
  types = import ./lib/types.nix { inherit lib; };
in {
  options.features.bootentry-manager = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = featureVersion;
      internal = true;
      description = "Feature version";
    };

    enable = lib.mkEnableOption "boot entry manager";
    
    description = lib.mkOption {
      type = types.str;
      default = "Boot entry management for various bootloaders";
      description = "Feature description";
    };
  };
}

