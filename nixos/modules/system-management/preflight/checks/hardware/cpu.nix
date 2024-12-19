{ config, lib, pkgs, ... }:

let
  preflightScript = pkgs.writeScriptBin "preflight-check-cpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # Add color definitions
    RED='\033[0;31m'
    NC='\033[0m' # No Color

    echo "Checking CPU configuration..."
    
    # CPU Detection using lscpu
    if ! CPU_INFO=$(${pkgs.util-linux}/bin/lscpu); then
      echo -e "''${RED}Error: Could not detect CPU information''${NC}"
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
      echo -e "''${RED}Error: system-config.nix not found''${NC}"
      exit 1
    fi
    
    if ! CONFIGURED=$(grep 'cpu =' /etc/nixos/system-config.nix | cut -d'"' -f2); then
      echo -e "''${RED}Error: Could not find CPU configuration in system-config.nix''${NC}"
      exit 1
    fi
    
    echo "Detected CPU: $DETECTED"
    echo "Configured CPU: $CONFIGURED"
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      echo -e "''${RED}WARNING: CPU configuration mismatch!''${NC}"
      echo -e "''${RED}System configured for $CONFIGURED but detected $DETECTED''${NC}"
      
      echo "Updating system-config.nix..."
      echo "Original line: $(grep 'cpu =' /etc/nixos/system-config.nix)"
      
      # Update CPU configuration
      sed -i "s/cpu = \"$CONFIGURED\"/cpu = \"$DETECTED\"/" /etc/nixos/system-config.nix
      
      echo "Updated line: $(grep 'cpu =' /etc/nixos/system-config.nix)"
    fi
    
    echo "CPU check completed."
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