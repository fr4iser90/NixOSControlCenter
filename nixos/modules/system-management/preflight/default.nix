# modules/system-management/preflight/default.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  checkAndBuild = pkgs.writeShellScriptBin "check-and-build" ''
    #!${pkgs.bash}/bin/bash
    
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
      echo "Example: check-and-build switch --flake /etc/nixos#Gaming"
      exit 1
    fi

    echo "Running preflight checks..."
    if ! run-system.preflight.checks; then
      echo "Preflight checks failed!"
      exit 1
    fi

    echo "Checks passed! Running nixos-rebuild..."
    exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild "$@"
  '';

in
{
  imports = [
    ./checks/hardware/gpu.nix
    ./checks/system/users.nix
    ./runners/cli.nix
  ];

  config = {
    environment.systemPackages = [
      checkAndBuild
    ];
  };
}