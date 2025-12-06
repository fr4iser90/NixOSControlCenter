{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  ui = config.core.cli-formatter.api;
  commandCenter = config.core.command-center;
  hostname = systemConfig.hostName;

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
    # Use enable-desktop from desktop-manager feature
    if command -v enable-desktop >/dev/null 2>&1; then
      enable-desktop disable
    else
      echo "Error: enable-desktop command not found. Is desktop-manager feature enabled?"
      exit 1
    fi

    echo "Enabling SSH Client & Server Manager..."
    # Use update-features-config from feature-manager or system-config-manager
    if command -v update-features-config >/dev/null 2>&1; then
      update-features-config ssh-client-manager true
      update-features-config ssh-server-manager true
    else
      echo "Error: update-features-config command not found. Is feature-manager or system-config-manager enabled?"
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

    core.command-center.commands = [
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
    ];
  };
}
