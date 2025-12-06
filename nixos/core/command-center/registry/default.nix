{ config, lib, ... }:

with lib;

let
  types = import ./types.nix { inherit lib; };
  cfg = config.core.command-center;

  # Automatisch alle verwendeten Kategorien sammeln
  usedCategories = lib.unique (
    lib.map (command: command.category) cfg.commands
  );
in {
  options.core.command-center = {
    commands = mkOption {
      type = lib.types.listOf types.commandType;
      default = [];
      description = "Available commands for the NixOS Control Center";
    };

    # Kategorien werden automatisch erkannt
    categories = mkOption {
      type = lib.types.listOf lib.types.str;
      default = usedCategories;
      description = "Currently used command categories";
      internal = true;  # Nicht manuell setzen
    };
  };
}