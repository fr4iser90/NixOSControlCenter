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
        Override for the Host NixOS tree used by `ncc install` (rsync source on remote deploy).
        Live NCC hosts: usually `/etc/nixos` (auto-detected). Dev checkout: repo root or
        path with `nixos/` subdir. Empty = `/etc/nixos` then cwd walk. Env: `NCC_INSTALL_REPO`.
      '';
    };
  };
}
