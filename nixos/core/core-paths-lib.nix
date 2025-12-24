# Core Paths Library - Reine Funktionen, keine Module-Abhängigkeiten
# Clean Nix Style: Library-Funktionen wie getModuleConfig
{ lib }:

let
  # Basis-Pfade (Single Source of Truth)
  paths = {
    cliRegistryCommands = "core.management.system-manager.submodules.cli-registry.commands";
    cliRegistryApi = "core.management.system-manager.submodules.cli-registry.api";
    systemManagerApi = "core.management.system-manager.api";
  };

in {
  # Pfad-Getter Funktionen
  getCliRegistryCommandsPath = paths.cliRegistryCommands;
  getCliRegistryApiPath = paths.cliRegistryApi;
  getSystemManagerApiPath = paths.systemManagerApi;

  # Helper für lib.setAttrByPath
  getCliRegistryCommandsPathList = lib.splitString "." paths.cliRegistryCommands;
  getCliRegistryApiPathList = lib.splitString "." paths.cliRegistryApi;
  getSystemManagerApiPathList = lib.splitString "." paths.systemManagerApi;

  # Direkter Zugriff auf alle Pfade
  inherit paths;
}
