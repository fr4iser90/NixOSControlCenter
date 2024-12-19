# modules/system-management/preflight/default.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  checkAndBuild = pkgs.writeShellScriptBin "check-and-build" ''
    #!${pkgs.bash}/bin/bash
    
    # Add color definitions
    RED='\033[0;31m'
    GREEN='\033[0;32m'
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
      echo ""
      echo "Options:"
      echo "  --force     - Skip all preflight checks"
      echo ""
      echo "Example: check-and-build switch --flake /etc/nixos#Gaming"
      echo "         check-and-build switch --force"
      exit 1
    fi

    # Prüfe ob --force verwendet wird
    if [[ " $* " =~ " --force " ]]; then
      echo -e "''${RED}WARNING: Bypassing preflight checks!''${NC}"
      echo "Running nixos-rebuild..."
      # Entferne --force Option
      args=$(echo "$@" | sed 's/--force//')
      exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild $args
    fi

    echo "Running preflight checks..."
    
    # Führe Checks aus
    if ! preflight-check-users; then
      echo -e "''${RED}User checks failed!''${NC}"
      echo -e "Use --force to bypass checks"
      exit 1
    fi

    if ! run-system.preflight.checks; then
      echo -e "''${RED}System checks failed!''${NC}"
      echo -e "''${RED}To bypass checks, use: check-and-build <command> --force''${NC}"
      exit 1
    fi

    echo -e "''${GREEN}All checks passed!''${NC}"
    echo "Running nixos-rebuild..."
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