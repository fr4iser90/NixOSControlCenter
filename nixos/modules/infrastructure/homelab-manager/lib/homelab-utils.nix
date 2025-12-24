{ config, lib, pkgs, systemConfig, getModuleConfig, corePathsLib, ... }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  commandCenter = config.core.management.system-manager.submodules.cli-registry;
  hostname = lib.attrByPath ["hostName"] "nixos" (getModuleConfig "network");

  # Homelab Minimization Script
  # Converts a desktop system to a minimal homelab server by:
  # - Disabling desktop environment
  # - Enabling SSH client and server managers
  minimizeScript = pkgs.writeScriptBin "ncc-homelab-minimize" ''
    #!${pkgs.bash}/bin/bash
    set -e
    
    # Sudo check
    if [ "$EUID" -ne 0 ]; then
      echo "Error: This script must be run as root (use sudo)"
      exit 1
    fi

    echo "Disabling desktop..."
    # Use enable-desktop from desktop-manager module
    if command -v enable-desktop >/dev/null 2>&1; then
      enable-desktop disable
    else
      echo "Error: enable-desktop command not found. Is desktop-manager module enabled?"
      exit 1
    fi

    echo "Enabling SSH Client & Server Manager..."
    # Use update-modules-config from module-manager or system-config-manager
    if command -v update-modules-config >/dev/null 2>&1; then
      update-modules-config ssh-client-manager true
      update-modules-config ssh-server-manager true
    else
      echo "Error: update-modules-config command not found. Is module-manager or system-config-manager enabled?"
      exit 1
    fi

    echo "Applying changes with nixos-rebuild..."
    if sudo nixos-rebuild switch --flake /etc/nixos#${hostname}; then
      echo "System successfully minimized!"
    else
      echo "Rebuild failed! Check logs for details."
      exit 1
    fi
  '';

in {
  config = {
    environment.systemPackages = [
      minimizeScript
    ];

    config = lib.mkMerge [
      (lib.setAttrByPath corePathsLib.getCliRegistryCommandsPathList [
      {
        name = "homelab-minimize";
        description = "Minimize system configuration for homelab use";
        category = "system";
        script = "${minimizeScript}/bin/ncc-homelab-minimize";
        arguments = [];
        dependencies = [ "nix" ];
        shortHelp = "homelab-minimize - Disable desktop and enable SSH";
        longHelp = ''
          Minimizes system configuration by:
          - Disabling desktop environment
          - Enabling SSH client and server managers
          Requires sudo privileges and triggers system rebuild.
        '';
      }
      ])
    ];
  };
}
