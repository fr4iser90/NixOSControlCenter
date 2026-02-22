# Build script for NixOS ISO with KDE Plasma 6 Desktop
# Usage: nix-build build-iso-plasma6.nix

let
  # Import nixpkgs with system
  nixpkgs = import <nixpkgs> {
    system = "x86_64-linux";
  };
  
  # Build NixOS system with ISO configuration (Plasma 6)
  isoSystem = import <nixpkgs/nixos/lib/eval-config.nix> {
    system = "x86_64-linux";
    modules = [
      ./iso-config.nix
      {
        # Override desktop environment to Plasma 6
        _module.args.desktopEnv = "plasma6";
      }
    ];
  };
in
  isoSystem.config.system.build.isoImage
