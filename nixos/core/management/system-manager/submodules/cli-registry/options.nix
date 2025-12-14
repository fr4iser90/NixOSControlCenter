{ lib, ... }:

let
  moduleVersion = "1.0";  # Current module version
  ccLib = import ./lib { inherit lib; };
in {
  options.systemConfig.core.management.system-manager.submodules.cli-registry = {
    # Version metadata (required for all modules)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
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
  options.core.command-center = {
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
