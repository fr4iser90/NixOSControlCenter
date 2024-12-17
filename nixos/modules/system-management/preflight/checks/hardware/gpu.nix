# modules/system-management/preflight/checks/hardware/gpu.nix
{ config, lib, pkgs, ... }:

let
  preflightScript = pkgs.writeScriptBin "check-gpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Add color definitions
    RED='\033[0;31m'
    NC='\033[0m' # No Color
    
    echo "Checking GPU configuration..."
    
    # GPU Detection
    if ! GPU_INFO=$(${pkgs.pciutils}/bin/lspci | grep -E 'VGA|3D|2D'); then
      echo -e "''${RED}Error: Could not detect any GPU devices''${NC}"
      exit 1
    fi
    
    # Präzisere GPU-Erkennung
    if echo "$GPU_INFO" | grep -qi "nvidia.*intel\|intel.*nvidia"; then
      DETECTED="nvidia-intel"
    elif echo "$GPU_INFO" | grep -qi "\\(amd\\|ati\\).*intel\|intel.*(amd\\|ati)"; then
      DETECTED="amd-intel"
    elif echo "$GPU_INFO" | grep -qi "nvidia"; then
      DETECTED="nvidia"
    elif echo "$GPU_INFO" | grep -qi "\\(amd\\|ati\\)"; then
      DETECTED="amd"
    elif echo "$GPU_INFO" | grep -qi "intel"; then
      DETECTED="intel"
    else
      DETECTED="generic"
    fi
    
    if [ ! -f /etc/nixos/system-config.nix ]; then
      echo "Error: system-config.nix not found"
      exit 1
    fi
    
    if ! CONFIGURED=$(grep 'gpu =' /etc/nixos/system-config.nix | cut -d'"' -f2); then
      echo "Error: Could not find GPU configuration in system-config.nix"
      exit 1
    fi
    
    echo "Detected GPU: $DETECTED"
    echo "Configured GPU: $CONFIGURED"
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      echo -e "''${RED}WARNING: GPU configuration mismatch!''${NC}"
      echo -e "''${RED}System configured for $CONFIGURED but detected $DETECTED''${NC}"

      # Create backup of system-config.nix
      cp /etc/nixos/system-config.nix /etc/nixos/system-config.nix.bak.gpu

      echo "Updating system-config.nix..."
      echo "Original line: $(grep 'gpu =' /etc/nixos/system-config.nix)"

      # Update GPU configuration
      sed -i "s/gpu = \"$CONFIGURED\"/gpu = \"$DETECTED\"/" /etc/nixos/system-config.nix

      echo "Updated line: $(grep 'gpu =' /etc/nixos/system-config.nix)"
      echo "Configuration updated. Original config backed up to system-config.nix.bak.gpu"
    fi
    
    echo "GPU check completed."
    exit 0
  '';

in {
  config = {
    system.preflight.checks.gpu = {
      check = preflightScript;
      name = "GPU Check";
      binary = "check-gpu";
    };
    environment.systemPackages = [ preflightScript ];
  };
}

