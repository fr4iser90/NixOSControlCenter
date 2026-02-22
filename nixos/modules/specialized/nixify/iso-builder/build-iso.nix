# Build script for NixOS ISO with Calamares and NixOS Control Center
# Usage: nix-build build-iso.nix

let
  # Import nixpkgs with system
  nixpkgs = import <nixpkgs> {
    system = "x86_64-linux";
  };
  
  # Build NixOS system with ISO configuration
  # Use eval-config.nix directly
  # Default to plasma6 if not specified
  isoSystem = import <nixpkgs/nixos/lib/eval-config.nix> {
    system = "x86_64-linux";
    specialArgs = {
      desktopEnv = "plasma6";  # Default for build-iso.nix
    };
    modules = [
      ./iso-config.nix
    ];
  };
in
  isoSystem.config.system.build.isoImage
