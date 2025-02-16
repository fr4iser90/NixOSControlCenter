{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  ui = config.features.terminal-ui.api;
  commandCenter = config.features.command-center;
  hostname = systemConfig.hostName;
  configPath = "/etc/nixos/system-config.nix";

  minimizeScript = pkgs.writeScriptBin "ncc-homelab-minimize" ''
    #!${pkgs.bash}/bin/bash
    set -e
    
    # Sudo check
    if [ "$EUID" -ne 0 ]; then
      echo "Error: This script must be run as root (use sudo)"
      exit 1
    fi

    echo "Disabling desktop..."
    if ! ${pkgs.gnused}/bin/sed -i \
      's/\(\s*enable\s*=\s*\)\(true\|false\)\s*;/\1false;/' ${configPath}; then
      echo "Failed to disable desktop"
      exit 1
    fi

    echo "Enabling SSH Client & Server Manager..."
    if ! ${pkgs.gnused}/bin/sed -i \
      's/\(\s*ssh-client-manager\s*=\s*\)\(true\|false\)\s*;/\1true;/' ${configPath}; then
      echo "Failed to enable SSH Client Manager"
      exit 1
    fi

    if ! ${pkgs.gnused}/bin/sed -i \
      's/\(\s*ssh-server-manager\s*=\s*\)\(true\|false\)\s*;/\1true;/' ${configPath}; then
      echo "Failed to enable SSH Server Manager"
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
  enableDesktopScript = pkgs.writeScriptBin "enable-desktop" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Sudo check
    if [ "$EUID" -ne 0 ]; then
      echo "This script must be run as root (use sudo)"
      exit 1
    fi

    # Enable or disable desktop
    if [ "$1" == "disable" ]; then
      echo "Disabling desktop..."
      ${pkgs.gnused}/bin/sed -i 's/desktop.enable = true;/desktop.enable = false;/g' /etc/nixos/configuration.nix
    elif [ "$1" == "enable" ]; then
      echo "Enabling desktop..."
      ${pkgs.gnused}/bin/sed -i 's/desktop.enable = false;/desktop.enable = true;/g' /etc/nixos/configuration.nix
    else
      echo "Invalid option. Use 'enable' or 'disable'."
      exit 1
    fi

    # Apply the changes
    echo "Rebuilding system..."
    sudo nixos-rebuild switch

    echo "Desktop configuration updated successfully!"
  '';

in {
  config = {
    environment.systemPackages = [ desktopManagerScript ];

    features.command-center.commands = [
      {
        name = "desktop-manager";
        description = "Dekstop manager";
        category = "system";
        script = "${desktopManagerScript}/bin/ncc-desktop-manager";
        arguments = [];
        dependencies = [ "nix" "gnused" ];
        shortHelp = "homelab-minimize - Disable desktop and enable SSH";
        longHelp = ''

          Requires sudo privileges and triggers system rebuild.
        '';
      }
    ];
  };
}
