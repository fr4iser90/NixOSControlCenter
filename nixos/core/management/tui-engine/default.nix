{ config, lib, pkgs, buildGoApplication, gomod2nix, ... }:

let
  moduleName = baseNameOf ./. ;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Bubble Tea TUI utilities for NixOS Control Center";
    category = "management";
    subcategory = "tui-engine";
    stability = "stable";
    version = "1.0.0";
  };

  imports = [
    ./options.nix
    (import ./config.nix { inherit config lib pkgs buildGoApplication gomod2nix; })
  ];
}
