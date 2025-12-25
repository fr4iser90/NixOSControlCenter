{ lib, getCurrentModuleMetadata, ... }:

let
  # NCC API - greift direkt auf Submodule APIs zu
  formatter = import ./submodules/cli-formatter/api.nix { inherit lib; };
  registry = import ./submodules/cli-registry/api.nix { inherit lib; };

  # Jetzt GENERISCH wie options.nix!
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
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
