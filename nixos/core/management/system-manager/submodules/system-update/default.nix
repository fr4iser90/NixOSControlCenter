{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:
let
  # Single Source: Modulname nur einmal definieren
  moduleName = "system-update";
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "System update and package management";
    category = "management";
    subcategory = "system-manager.submodules.system-update";
    stability = "stable";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

  imports = [
    ./options.nix
  ] ++ (if (cfg.enable or true) then [
    ./commands.nix  # System update commands
    ./config.nix    # System update implementation
    ./handlers/system-update.nix  # System update handler
  ] else []);
}
