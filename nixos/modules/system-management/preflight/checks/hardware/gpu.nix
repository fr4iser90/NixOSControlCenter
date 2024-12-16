# modules/system-management/preflight/checks/hardware/gpu.nix
{ config, lib, pkgs, ... }:

let
  preflightScript = pkgs.writeScriptBin "nixos-rebuild-preflight" ''
    #!${pkgs.bash}/bin/bash
    set -e
    
    echo "Running preflight checks..."
    
    # GPU Detection
    echo "Checking GPU configuration..."
    GPU_INFO=$(${pkgs.pciutils}/bin/lspci | grep -E 'VGA|3D|2D')
    
    if echo "$GPU_INFO" | grep -q "NVIDIA" && echo "$GPU_INFO" | grep -q "Intel"; then
      DETECTED="nvidiaIntelPrime"
    elif echo "$GPU_INFO" | grep -q "AMD\|ATI" && echo "$GPU_INFO" | grep -q "Intel"; then
      DETECTED="amdIntelPrime"
    elif echo "$GPU_INFO" | grep -q "NVIDIA"; then
      DETECTED="nvidia"
    elif echo "$GPU_INFO" | grep -q "AMD\|ATI"; then
      DETECTED="amdgpu"
    elif echo "$GPU_INFO" | grep -q "Intel"; then
      DETECTED="intel"
    else
      DETECTED="generic"
    fi
    
    CONFIGURED=$(grep 'gpu =' /etc/nixos/system-config.nix | cut -d'"' -f2)
    
    echo "Detected GPU: $DETECTED"
    echo "Configured GPU: $CONFIGURED"
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      echo "WARNING: GPU configuration mismatch!"
      read -p "Continue anyway? [y/N] " response
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Aborting system rebuild."
        exit 1
      fi
    fi
    
    # Wenn alles OK, führe den eigentlichen nixos-rebuild aus
    exec nixos-rebuild "$@"
  '';

in {
  config = {
    environment.systemPackages = [ preflightScript ];
    programs.bash.shellAliases = {
      "nixos-rebuild" = "nixos-rebuild-preflight";
    };
  };
}