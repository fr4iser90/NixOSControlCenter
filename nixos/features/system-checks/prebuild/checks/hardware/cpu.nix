{ config, lib, pkgs, systemConfig, ... }:

let
  ui = config.features.terminal-ui.api;

  prebuildScript = pkgs.writeScriptBin "prebuild-check-cpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # CPU Detection using lscpu
    if ! CPU_INFO=$(${pkgs.util-linux}/bin/lscpu); then
      ${ui.messages.error "Could not detect CPU information"}
      exit 1
    fi
    
    # CPU Vendor Detection
    if echo "$CPU_INFO" | grep -qi "GenuineIntel"; then
      DETECTED="intel"
    elif echo "$CPU_INFO" | grep -qi "AuthenticAMD"; then
      DETECTED="amd" 
    else
      DETECTED="generic"
    fi
    
    if [ ! -f /etc/nixos/system-config.nix ]; then
      ${ui.messages.error "system-config.nix not found"}
      exit 1
    fi
    
    if ! CONFIGURED=$(grep 'cpu =' /etc/nixos/system-config.nix | cut -d'"' -f2); then
      ${ui.messages.error "Could not find CPU configuration in system-config.nix"}
      exit 1
    fi
    
    # Immer Info anzeigen
    ${ui.messages.info "Detected CPU: $DETECTED"}
    ${ui.messages.info "Configured CPU: $CONFIGURED"}
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      ${ui.messages.warning "CPU configuration mismatch!"}
      ${ui.messages.warning "System configured for $CONFIGURED but detected $DETECTED"}
      
      # Update CPU configuration
      sed -i "s/cpu = \"$CONFIGURED\"/cpu = \"$DETECTED\"/" /etc/nixos/system-config.nix
      ${ui.badges.success "Configuration updated."}
    else
      ${ui.badges.success "CPU configuration matches hardware."}
    fi
    
    exit 0
  '';

in {
  config = {
    environment.systemPackages = [ prebuildScript ];  # Nur Script installieren
  };
}