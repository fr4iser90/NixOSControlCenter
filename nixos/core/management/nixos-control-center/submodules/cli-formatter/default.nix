{ config, lib, pkgs, systemConfig, getModuleConfig, getCurrentModuleMetadata, ... }:

let
  # Single Source: Modulname nur einmal definieren
  moduleName = baseNameOf ./. ;  # ← cli-formatter aus submodules/cli-formatter/

in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "CLI formatting utilities for system output";
    category = "management";
    subcategory = "nixos-control-center.submodules.cli-formatter";
    stability = "stable";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

  imports = [
    ./options.nix
    (import ./config.nix { inherit config lib pkgs systemConfig getModuleConfig getCurrentModuleMetadata moduleName; })
  ];
}
