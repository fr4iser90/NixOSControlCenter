# Library exports - Template-konform: nur Imports, keine Logik
{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, ... }:

let
  # Own lib — same module, OK
  discovery = import ./discovery.nix { inherit lib; };
  utils = import ./utils.nix {
    inherit config lib pkgs systemConfig getModuleConfig getModuleApi getModuleMetadata;
  };

in {
  inherit (discovery) discoverAllModules discoverModulesInDir;
  inherit (utils) allModules updateModuleConfig getModuleStatus enableModule disableModule formatModuleList;
}
