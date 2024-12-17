# modules/system-management/preflight/checks/hardware/gpu.nix
{ config, lib, pkgs, ... }:

let
  preflightScript = pkgs.writeScriptBin "gpu-check" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "Checking GPU configuration..."
    
    # GPU Detection
    if ! GPU_INFO=$(${pkgs.pciutils}/bin/lspci | grep -E 'VGA|3D|2D'); then
      echo "Error: Could not detect any GPU devices"
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
      echo "ERROR: GPU configuration mismatch!"
      echo "Your system is configured for $CONFIGURED but detected $DETECTED"
      exit 1
    fi
    
    echo "GPU configuration check passed."
    exit 0
  '';

in {
  config = {
    system.preflight.checks.gpu = {
      check = preflightScript;
      name = "GPU Check";
      binary = "gpu-check";
    };
  };
}