{ lib, getCurrentModuleMetadata, ... }:

let
  # NCC API - greift direkt auf Submodule APIs zu
  formatter = import ./submodules/cli-formatter/api.nix { inherit lib; };
  registry = import ./submodules/cli-registry/api.nix { inherit lib; };

  # GENERISCH: Config Path aus Metadata ableiten
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  # NCC Public API - GENERISCH unter configPath.api!
  ${configPath}.api = {
    inherit formatter registry;

    # NCC Convenience functions
    format = formatter;
    registerCommand = registry.register;
  };
}
