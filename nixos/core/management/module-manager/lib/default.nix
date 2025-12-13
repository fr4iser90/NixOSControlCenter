# Library exports - Template-konform: nur Imports, keine Logik
{ config, lib, pkgs, systemConfig, ... }:

let
  # Import discovery functions
  discovery = import ./discovery.nix { inherit lib; };

  # Import utility functions
  utils = import ./utils.nix { inherit config lib pkgs systemConfig; };

in {
  # Export discovery functions
  inherit (discovery) discoverAllModules discoverModulesInDir;

  # Export utility functions
  inherit (utils) allModules updateModuleConfig getModuleStatus enableModule disableModule formatModuleList;
}