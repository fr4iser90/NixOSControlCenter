# modules/system-management/preflight/default.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  checkAndBuild = pkgs.writeShellScriptBin "check-and-build" ''
    #!${pkgs.bash}/bin/bash
    
    # Add color definitions
    RED='\033[0;31m'
    NC='\033[0m'
    
    # Prüfe ob ein Argument übergeben wurde
    if [ $# -eq 0 ]; then
      echo "Usage: check-and-build <command> [options]"
      echo ""
      echo "Commands:"
      echo "  switch      - Build and activate configuration"
      echo "  boot        - Build configuration and make it the boot default"
      echo "  test        - Build and activate, but don't add to boot menu"
      echo "  build       - Build configuration only"
      echo "  force       - Ignore preflight checks and build configuration"
      echo ""
      echo "Example: check-and-build switch --flake /etc/nixos#Gaming"
      exit 1
    fi

    # Prüfe ob force verwendet wird
    if [ "$1" = "force" ]; then
      shift  # Entferne "force" aus den Argumenten
      echo -e "''${RED}WARNING: Bypassing preflight checks!''${NC}"
      echo "Running nixos-rebuild..."
      exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild "$@"
    fi

    echo "Running preflight checks..."
    
    # Direkt ausführen statt zu capturen
    if ! run-system.preflight.checks; then
      echo -e "''${RED}Preflight checks failed!''${NC}"
      echo -e "''${RED}To bypass checks, use: check-and-build force <command> [options]''${NC}"
      exit 1
    fi

    echo "Checks passed! Running nixos-rebuild..."
    exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild "$@"
  '';

in
{
  imports = [
    ./checks/hardware/gpu.nix
    ./checks/hardware/cpu.nix
    ./checks/system/users.nix
    ./runners/cli.nix
  ];

  config = {
    environment.systemPackages = [
      checkAndBuild
    ];
  };
}