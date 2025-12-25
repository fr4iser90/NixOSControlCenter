{ lib, getCurrentModuleMetadata, ... }:

let
  # Finde eigenes Modul aus PFAD! KEIN hardcoded Name!
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
  configPath = metadata.configPath;
in {
  # User configuration (accessed via ${configPath})
  options.${configPath} = {
    # Version metadata (REQUIRED for all modules)
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "CLI formatter module version";
    };

    enable = lib.mkEnableOption "CLI formatter";

    config = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "CLI formatter configuration options";
    };

    components = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "Enable this component";

          refreshInterval = lib.mkOption {
            type = lib.types.int;
            default = 5;
            description = "Refresh interval in seconds";
          };

          template = lib.mkOption {
            type = lib.types.lines;
            description = "Component template using CLI formatter API";
          };
        };
      });
      default = {};
      description = "Custom CLI formatter components";
    };

    # API option (without default - set in config.nix)
    api = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      description = "CLI formatter API for other modules";
    };
  };
}
