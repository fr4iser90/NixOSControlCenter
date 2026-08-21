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
      ${ui.messages.error "This script must be run as root (use sudo)"}
      exit 1
    fi

    ${ui.messages.loading "Disabling desktop…"}
    if command -v enable-desktop >/dev/null 2>&1; then
      enable-desktop disable
    else
      ${ui.messages.error "enable-desktop command not found. Is desktop-manager module enabled?"}
      exit 1
    fi

    ${ui.messages.loading "Enabling ssh-manager (server)…"}
    if command -v update-module-config >/dev/null 2>&1; then
      update-module-config ssh-manager true
      ${ui.messages.info "Optional: set client.enable = true in ssh-manager for outbound ncc ssh client"}
    elif command -v update-modules-config >/dev/null 2>&1; then
      update-modules-config ssh-manager true
    else
      ${ui.messages.error "update-module-config not found"}
      exit 1
    fi

    ${ui.messages.loading "Enabling stack-manager…"}
    if command -v update-module-config >/dev/null 2>&1; then
      update-module-config stack-manager true || true
    fi

    ${ui.messages.loading "Applying changes with nixos-rebuild…"}
    if sudo nixos-rebuild switch --flake /etc/nixos#${hostname}; then
      ${ui.messages.success "System successfully minimized for stack workloads"}
    else
      ${ui.messages.error "Rebuild failed! Check logs for details."}
      exit 1
    fi
  '';
in {
  config = {
    environment.systemPackages = [ minimizeScript ];
  };
}
