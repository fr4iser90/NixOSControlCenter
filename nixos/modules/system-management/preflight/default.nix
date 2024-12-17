# modules/system-management/preflight/default.nix
{ config, lib, pkgs, ... }:

let
  preflightWrapper = pkgs.writeScriptBin "flake-rebuild-with-checks" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Erst Preflight-Checks ausführen
    if ! run-system.preflight.checks; then
      exit 1
    fi

    # Alle originalen Argumente durchreichen
    exec nixos-rebuild "$@"
  '';
in
{
  imports = [
    ./checks/hardware/gpu.nix
    ./checks/system/users.nix
    ./runners/cli.nix
  ];

  config = lib.mkIf config.system.management.enablePreflight {
    environment.systemPackages = with pkgs; [
      pciutils
      coreutils
      gnugrep
      gawk
      jq
      preflightWrapper
    ];

    # Wrapper für alle nixos-rebuild Varianten
    programs.bash.shellAliases = lib.mkForce {
      "flake-rebuild" = "flake-rebuild-with-checks";
    };
  };
}