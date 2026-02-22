# Build script for NixOS ISO with XFCE Desktop
# Usage: nix-build build-iso-xfce.nix

let
  # Import nixpkgs with system
  nixpkgs = import <nixpkgs> {
    system = "x86_64-linux";
  };
  
  # Build NixOS system with ISO configuration (XFCE)
  isoSystem = import <nixpkgs/nixos/lib/eval-config.nix> {
    system = "x86_64-linux";
    modules = [
      ./iso-config.nix
      {
        # Override desktop environment to XFCE
        _module.args.desktopEnv = "xfce";
      }
    ];
  };
in
  isoSystem.config.system.build.isoImage
