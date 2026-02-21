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

  # CLI registry is always active (Core module, no enable option)
  imports = [
    ./options.nix      # Always import options first
    (import ./config.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi getCurrentModuleMetadata moduleName; })
  ];
}