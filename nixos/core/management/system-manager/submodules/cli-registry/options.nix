{ lib, getCurrentModuleMetadata, ... }:

let
  # Finde eigenes Modul aus PFAD! KEIN hardcoded Name!
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
  configPath = metadata.configPath or "systemConfig.core.management.system-manager.submodules.cli-registry";  # Fallback

  ccLib = import ./lib { inherit lib; };
in {
  options.${configPath} = {
    # Version metadata (required for all modules)
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;  # Hidden from users
      description = "Module version";
    };

    # For core modules, enable is usually true by default
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the NixOS Control Center command system";
    };

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
  options.core.management.system-manager.submodules.cli-registry = {
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

    categories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Currently used command categories";
      internal = true;
    };
  };

}
