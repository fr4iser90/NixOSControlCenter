{ config, lib, pkgs, systemConfig, getModuleConfig, getCurrentModuleMetadata, ... }:

let
  # Single Source: Modulname nur einmal definieren
  moduleName = baseNameOf ./. ;  # ← user aus core/base/user/
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "User account management and configuration";
    category = "base";
    subcategory = "user";
    version = "1.0.0";
  };

  imports = [
    ./options.nix
    (import ./config.nix { inherit config lib pkgs getModuleConfig moduleName; })
    (import ./commands.nix { inherit config lib pkgs systemConfig getCurrentModuleMetadata; })
    ./password-manager.nix
  ];
}
