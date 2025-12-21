{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.systemConfig.core.base.desktop = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Desktop module version";
    };

    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable desktop environment";
    };

    environment = lib.mkOption {
      type = lib.types.enum [ "plasma" "gnome" "xfce" ];
      default = "plasma";
      description = "Desktop environment to use";
    };

    display = {
      manager = lib.mkOption {
        type = lib.types.enum [ "sddm" "gdm" "lightdm" ];
        default = "sddm";
        description = "Display manager";
      };

      server = lib.mkOption {
        type = lib.types.enum [ "wayland" "x11" "hybrid" ];
        default = "wayland";
        description = "Display server";
      };

      session = lib.mkOption {
        type = lib.types.str;
        default = "plasma";
        description = "Display session";
      };
    };

    theme = {
      dark = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Use dark theme";
      };
    };
  };
}

