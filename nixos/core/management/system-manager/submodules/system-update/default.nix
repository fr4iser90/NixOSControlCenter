{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:
let
  # Single Source: Modulname nur einmal definieren
  moduleName = baseNameOf ./. ;  # ← system-update aus submodules/system-update/
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
  _module.args = {
    inherit moduleName getModuleConfig;
  };

  imports = [
    ./options.nix
  ] ++ (if (cfg.enable or true) then [
    ./commands.nix  # System update commands
    (import ./config.nix { inherit config lib pkgs systemConfig getModuleConfig moduleName; })
    ./handlers/system-update.nix  # System update handler
  ] else []);
}
