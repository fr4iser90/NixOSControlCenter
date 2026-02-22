# Build script for NixOS ISO with GNOME Desktop
# Usage: nix-build build-iso-gnome.nix

let
  # Import nixpkgs with system
  nixpkgs = import <nixpkgs> {
    system = "x86_64-linux";
  };
  
  # Build NixOS system with ISO configuration (GNOME)
  isoSystem = import <nixpkgs/nixos/lib/eval-config.nix> {
    system = "x86_64-linux";
    modules = [
      ./iso-config.nix
      {
        # Override desktop environment to GNOME
        _module.args.desktopEnv = "gnome";
      }
    ];
  };
in
  isoSystem.config.system.build.isoImage
