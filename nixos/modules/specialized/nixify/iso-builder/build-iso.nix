# Build script for NixOS ISO with Calamares and NixOS Control Center
# Usage: nix-build build-iso.nix
#
# CRITICAL: nixpkgs nur EINMAL importieren und Overlay darauf anwenden
# Dann dieses pkgs an eval-config.nix übergeben
# Das verhindert zwei nixpkgs-Instanzen → keine doppelte calamares-nixos-extensions

let
  # Path to Calamares modules (relative to this file)
  calamaresModulePath = ./calamares-modules/nixos-control-center;
  calamaresJobModulePath = ./calamares-modules/nixos-control-center-job;
  
  # Import overlay function
  calamaresOverlay = import ./calamares-overlay-function.nix {
    inherit calamaresModulePath calamaresJobModulePath;
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
    };
    modules = [
      ./iso-config.nix
    ];
  };
in
  isoSystem.config.system.build.isoImage
