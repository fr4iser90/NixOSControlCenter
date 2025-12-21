{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.systemConfig.core.base.localization = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
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
  };
}

