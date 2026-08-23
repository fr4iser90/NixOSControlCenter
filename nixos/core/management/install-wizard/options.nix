{ lib, getCurrentModuleMetadata, ... }:

let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.1.0";
      internal = true;
      description = "Module version";
    };

    repoPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Absolute path to the NixOSControlCenter repository checkout.
        Used by `ncc install` when not running inside the install nix-shell.
        Empty = auto-detect from cwd / common locations.
      '';
    };
  };
}
