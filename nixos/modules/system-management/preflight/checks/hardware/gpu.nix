# modules/system-management/preflight/checks/hardware/gpu.nix
{ config, lib, pkgs, reportingConfig, ... }:

let
  preflightScript = pkgs.writeScriptBin "preflight-check-gpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
        
    # Initialize DETECTED with a default value
    DETECTED="generic"
    
    # Physical hardware detection first
    declare -A gpu_types
    while IFS= read -r line; do
        bus_id=$(echo "$line" | cut -d' ' -f1)
        vendor_id=$(${pkgs.pciutils}/bin/lspci -n -s "$bus_id" | awk '{print $3}' | cut -d':' -f1)
        device=$(echo "$line" | sed 's/.*: //')
        
        case "$vendor_id" in
            "10de") gpu_types["nvidia"]=1 ;; # NVIDIA
            "1002") gpu_types["amd"]=1 ;;    # AMD
            "8086") gpu_types["intel"]=1 ;;   # Intel
        esac
        
        ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.detailed then ''
          ${reportingConfig.formatting.info "Found GPU:"}
          ${reportingConfig.formatting.keyValue "  Device" "$device"}
          ${reportingConfig.formatting.keyValue "  Bus ID" "$bus_id"}
          ${reportingConfig.formatting.keyValue "  Vendor ID" "$vendor_id"}
        '' else ""}
    done < <(${pkgs.pciutils}/bin/lspci | grep -E "VGA|3D|Display")

    # Determine GPU configuration
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
                
                ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.detailed then ''
                  ${reportingConfig.formatting.info "Virtual Machine: $virt_type"}
                  ${reportingConfig.formatting.info "Virtual Display: $DETECTED"}
                '' else ""}
            fi
        fi
    fi
    
    if [ ! -f /etc/nixos/system-config.nix ]; then
      ${reportingConfig.formatting.error "system-config.nix not found"}
      exit 1
    fi
    
    if ! CONFIGURED=$(grep 'gpu =' /etc/nixos/system-config.nix | cut -d'"' -f2); then
      ${reportingConfig.formatting.error "Could not find GPU configuration in system-config.nix"}
      exit 1
    fi
    
    ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then ''
      ${reportingConfig.formatting.info "GPU Configuration:"}
      ${reportingConfig.formatting.keyValue "  Detected" "$DETECTED"}
      ${reportingConfig.formatting.keyValue "  Configured" "$CONFIGURED"}
    '' else ""}
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      ${reportingConfig.formatting.warning "GPU configuration mismatch!"}
      ${reportingConfig.formatting.warning "System configured for $CONFIGURED but detected $DETECTED"}

      # Update configuration
      sed -i "s/gpu = \"$CONFIGURED\"/gpu = \"$DETECTED\"/" /etc/nixos/system-config.nix
      
      ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then ''
        ${reportingConfig.formatting.success "Configuration updated."}
      '' else ""}
    ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then ''
    else
      ${reportingConfig.formatting.success "GPU configuration matches hardware."}
    '' else ""}
    fi
    
    exit 0
  '';

in {
  config = {
    system.preflight.checks.gpu = {
      check = preflightScript;
      name = "GPU Check";
      binary = "preflight-check-gpu";
    };
    environment.systemPackages = [ preflightScript ];
  };
}

