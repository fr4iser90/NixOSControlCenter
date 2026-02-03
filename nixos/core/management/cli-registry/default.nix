{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, ... }:

let
  moduleName = baseNameOf ./. ;  # ← cli-registry aus submodules/cli-registry/
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "CLI command registration and management";
    category = "management";
    subcategory = "nixos-control-center.submodules.cli-registry";
    stability = "stable";
    version = "1.0.0";
  };

  # imports must be at top level
  imports = [
    ./options.nix      # Always import options first
  ] ++ (if (cfg.enable or true) then [
    (import ./config.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi getCurrentModuleMetadata moduleName; })
  ] else [
    (import ./config.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi getCurrentModuleMetadata moduleName; })
  ]);
}