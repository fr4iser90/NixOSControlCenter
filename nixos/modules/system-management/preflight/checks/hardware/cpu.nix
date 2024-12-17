{ config, lib, pkgs, ... }:

let
  preflightScript = pkgs.writeScriptBin "check-cpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "Checking CPU configuration..."
    
    # CPU Detection using lscpu
    if ! CPU_INFO=$(${pkgs.util-linux}/bin/lscpu); then
      echo "Error: Could not detect CPU information"
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
      echo "Error: system-config.nix not found"
      exit 1
    fi
    
    if ! CONFIGURED=$(grep 'cpu =' /etc/nixos/system-config.nix | cut -d'"' -f2); then
      echo "Error: Could not find CPU configuration in system-config.nix"
      exit 1
    fi
    
    echo "Detected CPU: $DETECTED"
    echo "Configured CPU: $CONFIGURED"
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      echo "ERROR: CPU configuration mismatch!"
      echo "Your system is configured for $CONFIGURED but detected $DETECTED"
      exit 1
    fi
    
    echo "CPU configuration check passed."
    exit 0
  '';

in {
  config = {
    system.preflight.checks.cpu = {
      check = preflightScript;
      name = "CPU Check";
      binary = "check-cpu";
    };
    environment.systemPackages = [ preflightScript ];
  };
}