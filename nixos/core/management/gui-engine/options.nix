{ lib, getCurrentModuleMetadata, ... }:

let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "GUI engine module version";
    };

    # Core module — always on; no user enable toggle.
    api = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      internal = true;
      description = "GUI engine API (also via getModuleApi \"gui-engine\")";
    };
  };
}
