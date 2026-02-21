{ lib, getCurrentModuleMetadata, ... }:

let
  # Finde eigenes Modul aus PFAD! KEIN hardcoded Name!
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
  configPath = metadata.configPath or "systemConfig.core.management.cli-registry";  # Fallback

  ccLib = {
    types = import ./lib/types.nix { inherit lib; };
  };
in {
  options.${configPath} = {
    # Version metadata (required for all modules)
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;  # Hidden from users
      description = "Module version";
    };

    # NOTE: No enable option - cli-registry is always active (Core module)

    # User preferences can be added here in future versions
    # For example:
    # theme = "dark";
    # aliases = {
    #   "update" = "system-update";
    # };

    # User-configurable commands (optional override)
    commands = lib.mkOption {
      type = lib.types.listOf ccLib.types.commandType;
      default = [];
      description = "Additional user-defined commands";
    };

    # Computed categories from commands (read-only for users)
    categories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Currently used command categories (computed automatically)";
      internal = true;
    };
  };

  # API definition - always available, conditionally populated
  options.core.management.cli-registry = {
    # API for other modules - always available
    api = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      internal = true;
      description = "CLI registry API for other modules";
    };

    commands = lib.mkOption {
      type = lib.types.listOf ccLib.types.commandType;
      default = [];
      description = "Available commands for the NixOS Control Center";
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
  };

}
