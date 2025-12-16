{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  ui = config.core.management.system-manager.submodules.cli-formatter.api;
  commandCenter = config.core.management.system-manager.submodules.cli-registry;
  hostname = systemConfig.core.base.network.hostName or "nixos";
  systemChecks = systemConfig.core.management.system-manager.submodules.system-checks.enable or false;

  # Script to update flake inputs (channels) and rebuild
  updateChannelsScript = pkgs.writeScriptBin "ncc-update-channels" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Sudo-Check
    if [ "$EUID" -ne 0 ]; then
      ${ui.messages.error "This script must be run as root (use sudo)"}
      ${ui.messages.info "Usage: sudo $0"}
      exit 1
    fi

    ${ui.text.header "NixOS Channel Update"}

    # Update flake inputs
    ${ui.messages.loading "Updating flake inputs (nix flake update)..."}
    if ! sudo nix flake update --flake /etc/nixos; then
      ${ui.messages.error "Failed to update flake inputs!"}
      exit 1
    else
      ${ui.messages.success "Flake inputs updated successfully."}
    fi

    # Rebuild system
    ${ui.messages.loading "Rebuilding system..."}
    BUILD_CMD="${if systemChecks then "sudo ncc build switch --flake /etc/nixos#${hostname}" else "sudo nixos-rebuild switch --flake /etc/nixos#${hostname}"}"
    
    if $BUILD_CMD 2>&1; then
      ${ui.messages.success "System successfully rebuilt!"}
    else
      EXIT_CODE=$?
      # Check if build was successful but switch failed (common with service reload errors)
      if [ -f /nix/var/nix/profiles/system ]; then
        CURRENT_GEN=$(readlink /nix/var/nix/profiles/system | cut -d'-' -f2)
        if [ -n "$CURRENT_GEN" ]; then
          ${ui.messages.warning "Build completed, but switch encountered issues (exit code: $EXIT_CODE)"}
          ${ui.messages.info "Current generation: $CURRENT_GEN"}
          ${ui.messages.info "Some services may have failed to reload (e.g., dbus-broker.service)"}
          ${ui.messages.info "This is often harmless - the system should still work correctly."}
          ${ui.messages.info "You can verify with: sudo nixos-rebuild switch --flake /etc/nixos#${hostname}"}
        else
          ${ui.messages.error "Rebuild failed! Check logs for details."}
          exit 1
        fi
      else
        ${ui.messages.error "Rebuild failed! Check logs for details."}
        exit 1
      fi
    fi
  '';

in {
  config = {
    environment.systemPackages = [
      updateChannelsScript
    ];

    core.management.system-manager.submodules.cli-registry.commands = [
      {
        name = "update-channels";
        description = "Update Nix flake inputs / channels and rebuild the system";
        category = "system";
        script = "${updateChannelsScript}/bin/ncc-update-channels";
        arguments = [];
        dependencies = [ "nix" ]; # Add ncc if ncc build switch is used and is a separate package
        shortHelp = "update-channels - Update flake inputs and rebuild";
        longHelp = ''
          Updates the flake inputs / channels by running 'nix flake update'
          and then rebuilds the system using 'nixos-rebuild switch'
          or 'ncc build switch' if system checks are enabled.
          Requires sudo privileges.
        '';
      }
    ];
  };
}
