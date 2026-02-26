# Build script for NixOS ISO with KDE Plasma 6 Desktop
# Usage: nix-build build-iso-plasma6.nix
# Usage (force rebuild): nix-build build-iso-plasma6.nix --arg forceRebuild true
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
  # If forceRebuild is true, use current time to force rebuild
  # If false, use fixed string to allow caching
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
  
  # Build NixOS system with ISO configuration (Plasma 6)
  # CRITICAL: pkgs explizit übergeben, damit alle Module dasselbe pkgs verwenden
  isoSystem = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    system = "x86_64-linux";
    pkgs = pkgs;  # CRITICAL: Overlay-appliziertes pkgs übergeben
    specialArgs = {
      desktopEnv = "plasma6";
      buildTimestamp = rebuildTimestamp;  # Pass timestamp to iso-config
    };
    modules = [
      ./iso-config.nix
    ];
  };
in
  isoSystem.config.system.build.isoImage
