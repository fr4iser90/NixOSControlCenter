{ config, lib, pkgs, systemConfig, ... }:

let
  # Single Source: Modulname nur einmal definieren
  moduleName = baseNameOf ./. ;  # ← cli-formatter aus submodules/cli-formatter/

in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "CLI formatting utilities for system output";
    category = "management";
    subcategory = "system-manager.submodules.cli-formatter";
    stability = "stable";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

  imports = [
    ./options.nix
    ./config.nix
  ];
}
