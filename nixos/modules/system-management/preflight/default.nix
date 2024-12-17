# modules/system-management/preflight/default.nix
{ config, lib, pkgs, ... }:

let
  preflightWrapper = pkgs.writeScriptBin "nixos-rebuild" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Erst Preflight-Checks ausführen
    if ! run-system.preflight.checks; then
      exit 1
    fi

    # Original nixos-rebuild mit allen Argumenten aufrufen
    exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild "$@"
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
  };
}