{ config, lib, pkgs, systemConfig, getModuleApi, ... }:

let
  # GENERISCH: CLI Formatter API über getModuleApi beziehen
  ui = getModuleApi "cli-formatter"; 

  hardwareConfigPath = "/etc/nixos/configs/core/base/hardware/config.nix";
  
  # Use the shared update-hardware-config script from utils.nix
  # It will be automatically available via systemPackages

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
      DETECTED="none"
    fi
    
    # Check if hardware-config.nix exists
    if [ ! -f "${hardwareConfigPath}" ]; then
      ${ui.messages.info "hardware-config.nix not found, creating it..."}
      update-hardware-config "${hardwareConfigPath}" "cpu" "$DETECTED"
      ${ui.badges.success "hardware-config.nix created with detected CPU."}
      exit 0
    fi
    
    if ! CONFIGURED=$(grep 'cpu =' "${hardwareConfigPath}" | cut -d'"' -f2); then
      ${ui.messages.error "Could not find CPU configuration in hardware-config.nix"}
      exit 1
    fi
    
    # Always show info
    ${ui.messages.info "Detected CPU: $DETECTED"}
    ${ui.messages.info "Configured CPU: $CONFIGURED"}
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      ${ui.messages.warning "CPU configuration mismatch!"}
      ${ui.messages.warning "System configured for $CONFIGURED but detected $DETECTED"}
      
      # Update CPU configuration (only CPU is changed, GPU/Memory remain unchanged)
      update-hardware-config "${hardwareConfigPath}" "cpu" "$DETECTED"
      ${ui.badges.success "Configuration updated."}
    else
      ${ui.badges.success "CPU configuration matches hardware."}
    fi
    
    exit 0
  '';

in {
  config = {
    environment.systemPackages = [ prebuildScript ];
  };
}
