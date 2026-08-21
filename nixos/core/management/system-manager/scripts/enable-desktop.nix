{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  hostname = lib.attrByPath ["hostName"] "nixos" (getModuleConfig "network");
  updateDesktopConfig = import ./update-desktop-config.nix { inherit config lib pkgs systemConfig; };
in
pkgs.writeScriptBin "enable-desktop" ''
  #!${pkgs.bash}/bin/bash
  set -e

  if [ -z "''${NCC_CLI_NESTED:-}" ]; then
    ${ui.text.header "Desktop Enable/Disable"}
  fi

  # Sudo check
  if [ "$EUID" -ne 0 ]; then
    ${ui.messages.error "This script must be run as root (use sudo)"}
    ${ui.messages.info "Next: sudo ncc system enable-desktop enable|disable"}
    exit 1
  fi

  # Enable or disable desktop
  if [ "$1" == "disable" ]; then
    ${ui.messages.loading "Disabling desktop..."}
    ${updateDesktopConfig}/bin/update-desktop-config "false"
  elif [ "$1" == "enable" ]; then
    ${ui.messages.loading "Enabling desktop..."}
    ${updateDesktopConfig}/bin/update-desktop-config "true"
  else
    ${ui.messages.error "Invalid option. Use 'enable' or 'disable'."}
    ${ui.messages.info "Next: sudo ncc system enable-desktop enable"}
    exit 1
  fi

  # Apply the changes
  ${ui.messages.loading "Rebuilding system..."}
  sudo nixos-rebuild switch --flake /etc/nixos#${hostname}

  ${ui.messages.success "Desktop configuration updated successfully!"}
  if [ -z "''${NCC_CLI_NESTED:-}" ]; then
    ${ui.messages.info "Next: reboot if the display manager changed"}
  fi
''
