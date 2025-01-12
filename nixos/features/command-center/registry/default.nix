{ config, lib, ... }:

with lib;

let
  types = import ./types.nix { inherit lib; };
  cfg = config.features.command-center;

  # Automatisch alle verwendeten Kategorien sammeln
  usedCategories = lib.unique (
    lib.mapAttrsToList (name: command: command.category) cfg.commands
  );
in {
  options.features.command-center = {
    commands = mkOption {
      type = lib.types.attrsOf types.commandType;
      default = {};
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