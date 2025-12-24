{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Single Source: Modulname nur einmal definieren
  moduleName = "system-logging";
  cfg = getModuleConfig moduleName;
in
{
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "System logging and reporting utilities";
    category = "management";
    subcategory = "system-manager.submodules.system-logging";
    stability = "stable";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

  imports = [
    ./options.nix
  ] ++ (lib.optionals (cfg.enable or true) [
    ./config.nix  # Import implementation logic
  ]);

}
