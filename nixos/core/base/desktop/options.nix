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
      description = "Desktop module version";
    };

    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
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

    # Taskbar / favorites pins (once per user unless force)
    pinnedApps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "firefox.desktop" "steam.desktop" ];
      description = ''
        .desktop IDs to pin on first login (taskbar/favorites).
        Empty + pinnedAppsAuto → derive from packages/modules via lib/pin-map.nix.
      '';
    };

    pinnedAppsAuto = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "When pinnedApps is empty, derive pins from packageModules/systemPackages.";
    };

    pinnedAppsForce = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Re-apply pins even if ~/.config/ncc/pinned-apps-applied exists.
        Leave false so user taskbar customizations survive rebuilds.
      '';
    };
  };
}

