{ lib, ... }:

let
  moduleVersion = "1.0";  # Current module version
  ccLib = import ./lib { inherit lib; };
in {
  options.systemConfig.command-center = {
    # Version metadata (REQUIRED for all modules)
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

    # Commands registry (moved from registry/default.nix)
    commands = lib.mkOption {
      type = lib.types.listOf ccLib.types.commandType;
      default = [];
      description = "Available commands for the NixOS Control Center";
    };

    # Categories are automatically detected from commands
    categories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];  # Will be computed in config
      description = "Currently used command categories";
      internal = true;  # Not manually set
    };

    # Additional configuration options can be added here
    # For example: theme, aliases, etc.
  };
}
