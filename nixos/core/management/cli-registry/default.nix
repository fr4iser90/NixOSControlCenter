{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, getCurrentModuleMetadata, ... }:

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

  # Explicit inherit: config.nix needs moduleName (not in flake specialArgs)
  imports = [
    ./options.nix
    (import ./config.nix {
      inherit config lib pkgs systemConfig getModuleConfig getModuleApi getModuleMetadata getCurrentModuleMetadata moduleName;
    })
  ];
}
