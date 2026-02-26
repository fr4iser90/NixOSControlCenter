# Build script for NixOS ISO with Calamares and NixOS Control Center
# Usage: nix-build build-iso.nix
# Usage (force rebuild): nix-build build-iso.nix --arg forceRebuild true
#
# CRITICAL: nixpkgs nur EINMAL importieren und Overlay darauf anwenden
# Dann dieses pkgs an eval-config.nix übergeben
# Das verhindert zwei nixpkgs-Instanzen → keine doppelte calamares-nixos-extensions

{ forceRebuild ? false }:

let
  # Path to Calamares modules (relative to this file)
  calamaresModulePath = ./calamares-modules/nixos-control-center;
  calamaresJobModulePath = ./calamares-modules/nixos-control-center-job;
  
  # Build timestamp for force rebuild
  rebuildTimestamp = if forceRebuild 
    then builtins.toString builtins.currentTime 
    else "cached";
  
  # Import overlay function with rebuild timestamp
  calamaresOverlay = import ./calamares-overlay-function.nix {
    inherit calamaresModulePath calamaresJobModulePath;
    buildTimestamp = rebuildTimestamp;
  };
  
  # Import nixpkgs EINMAL mit Overlay
  # CRITICAL: allowUnfree hier setzen, damit es für alle Pakete gilt
  pkgs = import <nixpkgs> {
    system = "x86_64-linux";
    config.allowUnfree = true;
    overlays = [ calamaresOverlay ];
  };
  
  # Build NixOS system with ISO configuration
  # Use eval-config.nix directly
  # Default to plasma6 if not specified
  # CRITICAL: pkgs explizit übergeben, damit alle Module dasselbe pkgs verwenden
  isoSystem = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    system = "x86_64-linux";
    pkgs = pkgs;  # CRITICAL: Overlay-appliziertes pkgs übergeben
    specialArgs = {
      desktopEnv = "plasma6";  # Default for build-iso.nix
      buildTimestamp = rebuildTimestamp;  # Pass timestamp to iso-config
    };
    modules = [
      ./iso-config.nix
    ];
  };
in
  isoSystem.config.system.build.isoImage
