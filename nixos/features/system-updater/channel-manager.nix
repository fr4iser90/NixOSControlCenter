{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  ui = config.features.terminal-ui.api;
  commandCenter = config.features.command-center;
  hostname = systemConfig.hostName;
  systemChecks = systemConfig.features.system-checks or false;

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
    if ${if systemChecks then "sudo ncc build switch --flake /etc/nixos#${hostname}" else "sudo nixos-rebuild switch --flake /etc/nixos#${hostname}"}; then
      ${ui.messages.success "System successfully rebuilt!"}
    else
      ${ui.messages.error "Rebuild failed! Check logs for details."}
      exit 1
    fi
  '';

in {
  config = {
    environment.systemPackages = [
      updateChannelsScript
    ];

    features.command-center.commands = [
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
