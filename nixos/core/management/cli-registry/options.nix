{ lib, getCurrentModuleMetadata, ... }:

let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;

  ccLib = {
    types = import ./lib/types.nix { inherit lib; };
  };
in {
  # Everything under discovery configPath (dotted key) — never options.core.management.…
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "Module version";
    };

    api = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      internal = true;
      description = "CLI registry API for other modules";
    };

    commands = lib.mkOption {
      type = lib.types.listOf ccLib.types.commandType;
      default = [];
      description = "Additional user-defined commands / available commands";
    };

    commandSets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf ccLib.types.commandType);
      default = {};
      description = "Command sets from different modules";
      internal = true;
    };

    categories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Currently used command categories";
      internal = true;
    };

    guiDomains = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          label = lib.mkOption {
            type = lib.types.str;
            description = "Sidebar label";
          };
          description = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Short description shown on the page";
          };
          enabled = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether the domain is usable (false → hidden when inactive)";
          };
          group = lib.mkOption {
            type = lib.types.enum [ "core" "features" ];
            default = "features";
            description = "Sidebar section: Core (always-on engines/base) vs Features (optional modules)";
          };
        };
      });
      default = {};
      internal = true;
      description = "GUI catalog stubs registered by modules";
    };

    guiPages = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.path;
            description = "Module ui/gui directory containing page.py";
          };
        };
      });
      default = {};
      internal = true;
      description = "Rich domain pages contributed by modules (not in gui-engine)";
    };
  };
}
