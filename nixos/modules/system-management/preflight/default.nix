# modules/system-management/preflight/default.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  preflightWrapper = pkgs.writeScriptBin "nixos-rebuild-with-checks" ''
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

  config = {
    environment.systemPackages = with pkgs; [
      pciutils
      coreutils
      gnugrep
      gawk
      jq
      preflightWrapper
      nixos-rebuild
    ];

    # Shell-Alias für nixos-rebuild
    programs.bash.shellAliases = {
      "nixos-rebuild" = "nixos-rebuild-with-checks";
    };
  };
}