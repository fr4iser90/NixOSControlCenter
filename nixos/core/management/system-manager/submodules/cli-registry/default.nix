{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  moduleName = baseNameOf ./. ;  # ← cli-registry aus submodules/cli-registry/
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "CLI command registration and management";
    category = "management";
    subcategory = "system-manager.submodules.cli-registry";
    stability = "stable";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

  # imports must be at top level
  imports = [
    ./options.nix      # Always import options first
  ] ++ (if (cfg.enable or true) then [
    (import ./config.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi moduleName; })
  ] else [
    (import ./config.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi moduleName; })
  ]);
}