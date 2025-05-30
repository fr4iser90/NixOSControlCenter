{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  ui = config.features.terminal-ui.api;
  commandCenter = config.features.command-center;
  hostname = systemConfig.hostName;
  configPath = "/etc/nixos/system-config.nix";

  # Minimizing Homelab
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

  # Enable or Disable Desktop
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
      ${pkgs.gnused}/bin/sed -i 's/desktop.enable = true;/desktop.enable = false;/g' ${configPath}
    elif [ "$1" == "enable" ]; then
      echo "Enabling desktop..."
      ${pkgs.gnused}/bin/sed -i 's/desktop.enable = false;/desktop.enable = true;/g' ${configPath}
    else
      echo "Invalid option. Use 'enable' or 'disable'."
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
      enableDesktopScript
    ];

    features.command-center.commands = [
      {
        name = "homelab-minimize";
        description = "Minimize system configuration for homelab use";
        category = "system";
        script = "${minimizeScript}/bin/ncc-homelab-minimize";
        arguments = [];
        dependencies = [ "nix" "gnused" ];
        shortHelp = "homelab-minimize - Disable desktop and enable SSH";
        longHelp = ''
          Minimizes system configuration by:
          - Disabling desktop environment
          - Enabling SSH client and server managers
          Requires sudo privileges and triggers system rebuild.
        '';
      }
      {
        name = "desktop-manager";
        description = "Enable or disable desktop environment";
        category = "system";
        script = "${enableDesktopScript}/bin/enable-desktop";
        arguments = [ "enable|disable" ];
        dependencies = [ "nix" "gnused" ];
        shortHelp = "Enable or disable the desktop environment";
        longHelp = ''
          Allows enabling or disabling the desktop environment:
          - "enable" to activate the desktop
          - "disable" to deactivate the desktop
          Requires sudo privileges and triggers system rebuild.
        '';
      }
    ];
  };
}