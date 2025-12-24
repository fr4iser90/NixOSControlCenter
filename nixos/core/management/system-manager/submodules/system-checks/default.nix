{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, ... }:

let
  # Single Source: Modulname nur einmal definieren
  moduleName = baseNameOf ./. ;  # ← system-checks aus submodules/system-checks/
  moduleMeta = getModuleMetadata moduleName;
  cfg = getModuleConfig moduleName;
in
{
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "System validation and health checks";
    category = "management";
    subcategory = "system-manager.submodules.system-checks";
    stability = "stable";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

  # imports must be at top level
  imports = [
    ./options.nix  # Always import options first
    ./commands.nix # Command registration (always needed)
  ] ++ (if (cfg.enable or true) then [
    (import ./config.nix { inherit config lib pkgs systemConfig getModuleApi moduleName; })
  ] else [
    (import ./config.nix { inherit config lib pkgs systemConfig getModuleApi moduleName; })
  ]);

}