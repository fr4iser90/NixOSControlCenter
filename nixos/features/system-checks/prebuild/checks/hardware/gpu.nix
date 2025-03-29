{ config, lib, pkgs, systemConfig, ... }:

let
  ui = config.features.terminal-ui.api;

  prebuildScript = pkgs.writeScriptBin "prebuild-check-gpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    ${ui.text.header "GPU Configuration Check"}
    
    # Initialize DETECTED with a default value
    DETECTED="generic"
    
    # Physical hardware detection first
    declare -A gpu_types
    amd_count=0
    
    while IFS= read -r line; do
        bus_id=$(echo "$line" | cut -d' ' -f1)
        vendor_id=$(${pkgs.pciutils}/bin/lspci -n -s "$bus_id" | awk '{print $3}' | cut -d':' -f1)
        device=$(echo "$line" | sed 's/.*: //')
        
        case "$vendor_id" in
            "10de") gpu_types["nvidia"]=1 ;; # NVIDIA
            "1002") 
                gpu_types["amd"]=1 
                amd_count=$((amd_count + 1))
                ;; # AMD
            "8086") gpu_types["intel"]=1 ;; # Intel
        esac
        
        # Immer GPU-Info anzeigen
        ${ui.messages.info "Found GPU:"}
        ${ui.tables.keyValue "Device" "$device"}
        ${ui.tables.keyValue "Bus ID" "$bus_id"}
        ${ui.tables.keyValue "Vendor ID" "$vendor_id"}
    done < <(${pkgs.pciutils}/bin/lspci | grep -E "VGA|3D|Display")

    # Debug info
    echo "AMD GPU count: $amd_count"
    
    # Determine GPU configuration
    if [[ ''${gpu_types["nvidia"]-0} -eq 1 && ''${gpu_types["intel"]-0} -eq 1 ]]; then
        DETECTED="nvidia-intel"
    elif [[ ''${gpu_types["amd"]-0} -eq 1 && ''${gpu_types["intel"]-0} -eq 1 ]]; then
        DETECTED="amd-intel"
    elif [[ $amd_count -eq 2 ]]; then
        DETECTED="amd-amd"
    elif [[ ''${gpu_types["nvidia"]-0} -eq 1 ]]; then
        DETECTED="nvidia"
    elif [[ ''${gpu_types["amd"]-0} -eq 1 ]]; then
        DETECTED="amd"
    elif [[ ''${gpu_types["intel"]-0} -eq 1 ]]; then
        DETECTED="intel"
    fi

    # Only check for VM if no physical GPU was detected
    if [ "$DETECTED" = "generic" ]; then
        if command -v ${pkgs.systemd}/bin/systemd-detect-virt &> /dev/null; then
            virt_type=$(${pkgs.systemd}/bin/systemd-detect-virt || echo "none")
            
            if [ "$virt_type" != "none" ]; then
                # Check for virtual GPU types
                if ${pkgs.pciutils}/bin/lspci | grep -qi "qxl"; then
                    DETECTED="qxl-virtual"
                elif ${pkgs.pciutils}/bin/lspci | grep -qi "virtio"; then
                    DETECTED="virtio-virtual"
                else
                    DETECTED="basic-virtual"
                fi
                
                # Immer VM-Info anzeigen
                ${ui.messages.info "Virtual Machine: $virt_type"}
                ${ui.messages.info "Virtual Display: $DETECTED"}
            fi
        fi
    fi
    
    if [ ! -f /etc/nixos/system-config.nix ]; then
      ${ui.messages.error "system-config.nix not found"}
      exit 1
    fi
    
    if ! CONFIGURED=$(grep 'gpu =' /etc/nixos/system-config.nix | cut -d'"' -f2); then
      ${ui.messages.error "Could not find GPU configuration in system-config.nix"}
      exit 1
    fi
    
    # Immer Konfiguration anzeigen
    ${ui.text.subHeader "GPU Configuration:"}
    ${ui.tables.keyValue "Detected" "$DETECTED"}
    ${ui.tables.keyValue "Configured" "$CONFIGURED"}
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      ${ui.messages.warning "GPU configuration mismatch!"}
      ${ui.messages.warning "System configured for $CONFIGURED but detected $DETECTED"}

      # Ask for confirmation
      read -p "Update GPU configuration to $DETECTED? [y/N] " response
      if [[ "$response" =~ ^[Yy]$ ]]; then
        # Update configuration
        sed -i "s/gpu = \"$CONFIGURED\"/gpu = \"$DETECTED\"/" /etc/nixos/system-config.nix
        ${ui.badges.success "Configuration updated."}
      else
        ${ui.badges.info "Configuration left unchanged."}
      fi
    else
      ${ui.badges.success "GPU configuration matches hardware."}
    fi
    
    exit 0
  '';

in {
  config = {
    environment.systemPackages = [ prebuildScript ];
    features.command-center.commands = [
      {
        name = "check-gpu";
        category = "system-checks";
        description = "Check GPU configuration before system rebuild";
        script = "${prebuildScript}/bin/prebuild-check-gpu";
        shortHelp = "check-gpu - Verify GPU configuration";
        longHelp = ''
          Check GPU configuration before system rebuild
          
          Checks:
          - Detects installed GPU hardware
          - Compares with configured GPU setting
          - Can update system-config.nix if needed
          
          Supports detection of:
          - NVIDIA, AMD, Intel graphics
          - Hybrid configurations
          - Virtual machine graphics
          
          Interactive: Yes (for updating configuration)
        '';
        interactive = true;
        dependencies = [ "system-checks" ];
      }
    ];
  };
}

