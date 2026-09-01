{ lib, getCurrentModuleMetadata, ... }:

let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
  catalog = import ./lib/rice-catalog.nix;
  riceIds = builtins.attrNames catalog;
in {
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.1.0";
      internal = true;
      description = "Hyprland module version";
    };

    enable = lib.mkEnableOption "Hyprland compositor with rice/wallpaper catalog";

    rice = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum riceIds);
      default = null;
      example = "astroland";
      description = ''
        Active Hall of Fame rice from the NCC store. Dotfiles rices are cloned to
        /var/lib/ncc/hyprland/collections/ on install; flake rices also patch flake.nix.
      '';
    };

    wallpaper = {
      rice = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum riceIds);
        default = null;
        example = "celestial";
        description = ''
          Wallpaper-only selection from the rice catalog (thumbnail from hypr.land).
          When null and rice is set, falls back to rice.
        '';
      };

      path = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/home/user/Pictures/wallpaper.png";
        description = "Override wallpaper with a local absolute path.";
      };
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra lines appended to generated hyprland.conf.";
    };

    packages = {
      waybar = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install waybar (minimal bar; full rice bars live in upstream dotfiles).";
      };

      hyprpaper = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install hyprpaper and wire wallpaper from catalog or path.";
      };
    };
  };
}
