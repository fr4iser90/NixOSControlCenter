{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Single Source: Modulname nur einmal definieren
  moduleName = baseNameOf ./. ;  # ← hardware aus core/base/hardware/
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Hardware detection and configuration";
    category = "base";
    subcategory = "hardware";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

  imports = [
    ./options.nix
    (import ./config.nix { inherit config lib getModuleConfig moduleName; })
    ./components/gpu
    ./components/cpu
    ./components/memory
  ];
}
