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

    enable = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Build and allow NCC Qt/PySide6 GUIs (`ncc`, `ncc <domain> --gui`).

        - null (default): auto — enabled when desktop is enabled, disabled on headless
        - true / false: explicit override in systemConfig

        Example (systemConfig):
          core.management.gui-engine.enable = false;
      '';
    };

    api = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      internal = true;
      description = "GUI engine API (also via getModuleApi \"gui-engine\")";
    };
  };
}
