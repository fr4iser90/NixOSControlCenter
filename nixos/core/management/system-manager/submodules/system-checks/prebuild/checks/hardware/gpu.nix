{ config, lib, pkgs, systemConfig, getModuleApi, corePathsLib, ... }:

let
  # ui = getModuleApi "cli-formatter";
  ui = config.core.management.system-manager.submodules.cli-formatter.api; 
  hardwareConfigPath = "/etc/nixos/configs/core/base/hardware/config.nix";
  
  # Use the shared update-hardware-config script from utils.nix
  # It will be automatically available via systemPackages

  prebuildScript = pkgs.writeScriptBin "prebuild-check-gpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    ${ui.text.header "GPU Configuration Check"}
    
    # Initialize DETECTED with a default value
    DETECTED="none"
    
    # Physical hardware detection first
    # Filter by device class code to only get actual GPUs:
    # 0300 = VGA compatible controller
    # 0302 = 3D controller
    # 0380 = Display controller
    declare -A gpu_types
    amd_count=0
    
    while IFS= read -r line; do
        bus_id=$(echo "$line" | cut -d' ' -f1)
        class_code=$(${pkgs.pciutils}/bin/lspci -n -s "$bus_id" | awk '{print $2}' | cut -d':' -f1)
        vendor_id=$(${pkgs.pciutils}/bin/lspci -n -s "$bus_id" | awk '{print $3}' | cut -d':' -f1)
        device=$(echo "$line" | sed 's/.*: //')
        
        # Only process actual GPU device classes (not audio controllers, etc.)
        case "$class_code" in
            "0300"|"0302"|"0380")  # VGA, 3D, or Display controller
                case "$vendor_id" in
                    "10de") gpu_types["nvidia"]=1 ;; # NVIDIA
                    "1002") 
                        gpu_types["amd"]=1 
                        amd_count=$((amd_count + 1))
                        ;; # AMD
                    "8086") gpu_types["intel"]=1 ;; # Intel
                esac
                
                # Always show GPU info
                ${ui.messages.info "Found GPU:"}
                ${ui.tables.keyValue "Device" "$device"}
                ${ui.tables.keyValue "Bus ID" "$bus_id"}
                ${ui.tables.keyValue "Vendor ID" "$vendor_id"}
                ${ui.tables.keyValue "Class Code" "$class_code"}
                ;;
        esac
    done < <(${pkgs.pciutils}/bin/lspci -nn | grep -E "\[0300\]|\[0302\]|\[0380\]")

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
    if [ "$DETECTED" = "none" ]; then
        if command -v ${pkgs.systemd}/bin/systemd-detect-virt &> /dev/null; then
            virt_type=$(${pkgs.systemd}/bin/systemd-detect-virt || echo "none")
            
            if [ "$virt_type" != "none" ]; then
                # Check for virtual GPU types
                if ${pkgs.pciutils}/bin/lspci | grep -qi "qxl"; then
                    DETECTED="vm-gpu"
                elif ${pkgs.pciutils}/bin/lspci | grep -qi "virtio"; then
                    DETECTED="vm-gpu"
                else
                    DETECTED="vm-gpu"
                fi
                
                # Always show VM info
                ${ui.messages.info "Virtual Machine: $virt_type"}
                ${ui.messages.info "Virtual Display: $DETECTED"}
            fi
        fi
    fi
    
    # Check if hardware-config.nix exists
    if [ ! -f "${hardwareConfigPath}" ]; then
      ${ui.messages.info "hardware-config.nix not found, creating it..."}
      
      # Ask for confirmation
      read -p "Create hardware-config.nix with detected GPU? [y/N] " response
      if [[ "$response" =~ ^[Yy]$ ]]; then
        update-hardware-config "${hardwareConfigPath}" "gpu" "$DETECTED"
        ${ui.badges.success "hardware-config.nix created."}
      else
        ${ui.badges.info "Configuration left unchanged."}
      fi
      exit 0
    fi
    
    if ! CONFIGURED=$(grep 'gpu =' "${hardwareConfigPath}" | cut -d'"' -f2); then
      ${ui.messages.error "Could not find GPU configuration in hardware-config.nix"}
      exit 1
    fi
    
    # Always show configuration
    ${ui.text.subHeader "GPU Configuration:"}
    ${ui.tables.keyValue "Detected" "$DETECTED"}
    ${ui.tables.keyValue "Configured" "$CONFIGURED"}
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      ${ui.messages.warning "GPU configuration mismatch!"}
      ${ui.messages.warning "System configured for $CONFIGURED but detected $DETECTED"}

      # Ask for confirmation
      read -p "Update GPU configuration to $DETECTED? [y/N] " response
      if [[ "$response" =~ ^[Yy]$ ]]; then
        update-hardware-config "${hardwareConfigPath}" "gpu" "$DETECTED"
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
  config = lib.mkMerge [
    {
      environment.systemPackages = [ prebuildScript ];
    }
    (lib.setAttrByPath corePathsLib.getCliRegistryCommandsPathList [
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
          - Can update hardware-config.nix if needed
          
          Supports detection of:
          - NVIDIA, AMD, Intel graphics
          - Hybrid configurations
          - Virtual machine graphics
          
          Interactive: Yes (for updating configuration)
        '';
        interactive = true;
        dependencies = [ "system-checks" ];
      }
      ])
  ];
}
