{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  hostname = lib.attrByPath [ "hostName" ] "nixos" (getModuleConfig "network");

  # Desktop → server-style host: disable DE, enable ssh-manager
  minimizeScript = pkgs.writeScriptBin "ncc-stacks-minimize" ''
    #!${pkgs.bash}/bin/bash
    set -e

    if [ "$EUID" -ne 0 ]; then
      echo "Error: This script must be run as root (use sudo)"
      exit 1
    fi

    echo "Disabling desktop..."
    if command -v enable-desktop >/dev/null 2>&1; then
      enable-desktop disable
    else
      echo "Error: enable-desktop command not found. Is desktop-manager module enabled?"
      exit 1
    fi

    echo "Enabling ssh-manager (server)..."
    if command -v update-module-config >/dev/null 2>&1; then
      update-module-config ssh-manager true
      echo "Optional: set client.enable = true in ssh-manager for outbound ncc ssh client"
    elif command -v update-modules-config >/dev/null 2>&1; then
      update-modules-config ssh-manager true
    else
      echo "Error: update-module-config not found"
      exit 1
    fi

    echo "Enabling stack-manager..."
    if command -v update-module-config >/dev/null 2>&1; then
      update-module-config stack-manager true || true
    fi

    echo "Applying changes with nixos-rebuild..."
    if sudo nixos-rebuild switch --flake /etc/nixos#${hostname}; then
      echo "System successfully minimized for stack workloads!"
    else
      echo "Rebuild failed! Check logs for details."
      exit 1
    fi
  '';
in {
  config = {
    environment.systemPackages = [ minimizeScript ];
  };
}
