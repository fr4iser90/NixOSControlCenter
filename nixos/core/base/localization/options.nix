{ lib, getCurrentModuleMetadata, ... }:

let
  # Finde eigenes Modul aus PFAD! KEIN hardcoded Name!
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
  configPath = metadata.configPath;
in {
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "Localization module version";
    };

    locales = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "en_US.UTF-8" ];
      description = "List of supported locales";
    };

    keyboardLayout = lib.mkOption {
      type = lib.types.str;
      default = "us";
      description = "Keyboard layout (e.g., 'us', 'de', 'fr')";
    };

    keyboardOptions = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Keyboard options (e.g., 'terminate:ctrl_alt_bksp')";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Berlin";
      description = "System timezone (e.g., 'Europe/Berlin', 'America/New_York', 'UTC')";
    };
  };
}

