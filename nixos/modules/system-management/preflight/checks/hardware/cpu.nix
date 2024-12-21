{ config, lib, pkgs, reportingConfig, ... }:

let
  preflightScript = pkgs.writeScriptBin "preflight-check-cpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    
    # CPU Detection using lscpu
    if ! CPU_INFO=$(${pkgs.util-linux}/bin/lscpu); then
      ${reportingConfig.formatting.error "Could not detect CPU information"}
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
      ${reportingConfig.formatting.error "system-config.nix not found"}
      exit 1
    fi
    
    if ! CONFIGURED=$(grep 'cpu =' /etc/nixos/system-config.nix | cut -d'"' -f2); then
      ${reportingConfig.formatting.error "Could not find CPU configuration in system-config.nix"}
      exit 1
    fi
    
    ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then ''
      ${reportingConfig.formatting.info "Detected CPU: $DETECTED"}
      ${reportingConfig.formatting.info "Configured CPU: $CONFIGURED"}
    '' else ""}
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      ${reportingConfig.formatting.warning "CPU configuration mismatch!"}
      ${reportingConfig.formatting.warning "System configured for $CONFIGURED but detected $DETECTED"}
      
      # Update CPU configuration
      sed -i "s/cpu = \"$CONFIGURED\"/cpu = \"$DETECTED\"/" /etc/nixos/system-config.nix
      
      ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then ''
        ${reportingConfig.formatting.success "Configuration updated."}
      '' else ""}
    ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then ''
    else
      ${reportingConfig.formatting.success "CPU configuration matches hardware."}
    '' else ""}
    fi
    
    exit 0
  '';

in {
  config = {
    system.preflight.checks.cpu = {
      check = preflightScript;
      name = "CPU Check";
      binary = "preflight-check-cpu";
    };
    environment.systemPackages = [ preflightScript ];
  };
}