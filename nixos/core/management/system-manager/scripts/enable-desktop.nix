{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  hostname = lib.attrByPath ["hostName"] "nixos" (getModuleConfig "network");
  desktopConfigPath = "/etc/nixos/configs/desktop-config.nix";

  updateDesktopConfig = import ./update-desktop-config.nix { inherit config lib pkgs systemConfig; };
in
pkgs.writeScriptBin "enable-desktop" ''
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
    ${updateDesktopConfig}/bin/update-desktop-config "false"
  elif [ "$1" == "enable" ]; then
    echo "Enabling desktop..."
    ${updateDesktopConfig}/bin/update-desktop-config "true"
  else
    echo "Invalid option. Use 'enable' or 'disable'."
    exit 1
  fi

  # Apply the changes
  echo "Rebuilding system..."
  sudo nixos-rebuild switch --flake /etc/nixos#${hostname}

  echo "Desktop configuration updated successfully!"
''
