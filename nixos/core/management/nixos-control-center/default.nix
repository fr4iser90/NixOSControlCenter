{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  moduleName = baseNameOf ./. ;  # "nixos-control-center"
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "NixOS Control Center - CLI ecosystem";
    category = "management";
    subcategory = "control-center";
    stability = "stable";
    version = "1.0.0";
  };

  _module.args.moduleName = moduleName;

  imports = [
    ./options.nix
    ./config.nix
    ./commands.nix
    ./api.nix
    # NCC importiert components
    # ./components/cli-formatter    # VERSCHOBEN von system-manager
    # ./components/cli-registry     # VERSCHOBEN von system-manager
  ];
}
