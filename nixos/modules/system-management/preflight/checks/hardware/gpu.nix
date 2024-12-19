# modules/system-management/preflight/checks/hardware/gpu.nix
{ config, lib, pkgs, ... }:

let
  preflightScript = pkgs.writeScriptBin "check-gpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Add color definitions
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    GRAY='\033[0;37m'
    NC='\033[0m'
    
    echo "Checking GPU configuration..."
    
    # GPU Detection
    if ! command -v ${pkgs.pciutils}/bin/lspci &> /dev/null; then
      echo -e "''${RED}Error: lspci not found''${NC}"
      exit 1
    fi

    # Array für gefundene GPUs
    declare -A gpu_types

    while IFS= read -r line; do
        bus_id=$(echo "$line" | cut -d' ' -f1)
        vendor_id=$(${pkgs.pciutils}/bin/lspci -n -s "$bus_id" | awk '{print $3}' | cut -d':' -f1)
        
        case "$vendor_id" in
            "10de") gpu_types["nvidia"]=1 ;; # NVIDIA
            "1002") gpu_types["amd"]=1 ;;    # AMD
            "8086") gpu_types["intel"]=1 ;;   # Intel
        esac
        
        echo -e "Found GPU:"
        echo -e "  Device   : ''${CYAN}$(echo "$line" | sed 's/.*: //')''${NC}"
        echo -e "  Bus ID   : ''${GRAY}$bus_id''${NC}"
        echo -e "  Vendor ID: ''${GRAY}$vendor_id''${NC}"
    done < <(${pkgs.pciutils}/bin/lspci | grep -E "VGA|3D|Display")

    # Bestimme GPU-Konfiguration
    if [[ ''${gpu_types["nvidia"]-0} -eq 1 && ''${gpu_types["intel"]-0} -eq 1 ]]; then
        DETECTED="nvidia-intel"
    elif [[ ''${gpu_types["amd"]-0} -eq 1 && ''${gpu_types["intel"]-0} -eq 1 ]]; then
        DETECTED="amd-intel"
    elif [[ ''${gpu_types["nvidia"]-0} -eq 1 ]]; then
        DETECTED="nvidia"
    elif [[ ''${gpu_types["amd"]-0} -eq 1 ]]; then
        DETECTED="amd"
    elif [[ ''${gpu_types["intel"]-0} -eq 1 ]]; then
        DETECTED="intel"
    else
        DETECTED="generic"
    fi
    
    if [ ! -f /etc/nixos/system-config.nix ]; then
      echo -e "''${RED}Error: system-config.nix not found''${NC}"
      exit 1
    fi
    
    if ! CONFIGURED=$(grep 'gpu =' /etc/nixos/system-config.nix | cut -d'"' -f2); then
      echo -e "''${RED}Error: Could not find GPU configuration in system-config.nix''${NC}"
      exit 1
    fi
    
    echo -e "\nGPU Configuration:"
    echo -e "  Detected  : ''${CYAN}$DETECTED''${NC}"
    echo -e "  Configured: ''${CYAN}$CONFIGURED''${NC}"
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      echo -e "\n''${RED}WARNING: GPU configuration mismatch!''${NC}"
      echo -e "''${RED}System configured for $CONFIGURED but detected $DETECTED''${NC}"

      # Create backup
      cp /etc/nixos/system-config.nix /etc/nixos/system-config.nix.bak.gpu
      echo -e "''${GRAY}Backup created: system-config.nix.bak.gpu''${NC}"

      # Update configuration
      sed -i "s/gpu = \"$CONFIGURED\"/gpu = \"$DETECTED\"/" /etc/nixos/system-config.nix
      echo -e "''${GREEN}Configuration updated to: $DETECTED''${NC}"
    else
      echo -e "\n''${GREEN}GPU configuration matches detected hardware.''${NC}"
    fi
    
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

