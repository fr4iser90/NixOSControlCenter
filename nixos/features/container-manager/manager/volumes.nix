{ config, pkgs, lib, ... }:

let
  volumeOptions = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.path;
        description = "Absolute path to the volume";
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = config.containerManager.containerManager;
        description = "Owner user of the volume";
      };
      group = lib.mkOption {
        type = lib.types.str;
        default = config.containerManager.containerManager;
        description = "Owner group of the volume";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "755";
        description = "Permissions mode for the volume";
      };
      backup = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable daily backups for this volume";
      };
      initData = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Initial data for volume initialization";
      };
    };
  };
in {
  options.containerManager.volumes = lib.mkOption {
    type = lib.types.attrsOf volumeOptions;
    default = {};
    description = "Volume configurations";
  };
}
