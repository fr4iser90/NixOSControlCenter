{ config, lib, pkgs, systemConfig, getModuleApi, ... }:

let
  cliRegistry = getModuleApi "cli-registry";
  ui = getModuleApi "cli-formatter"; 
  hardwareConfigPath = "/etc/nixos/systemConfig/core/base/hardware/config.nix";

  prebuildScript = pkgs.writeScriptBin "prebuild-check-gpu" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    ${ui.text.header "GPU Configuration Check"}
    
    DETECTED="none"
    
    declare -A gpu_types
    amd_count=0
    
    while IFS= read -r line; do
        bus_id=$(echo "$line" | cut -d' ' -f1)
        class_code=$(${pkgs.pciutils}/bin/lspci -n -s "$bus_id" | awk '{print $2}' | cut -d':' -f1)
        vendor_id=$(${pkgs.pciutils}/bin/lspci -n -s "$bus_id" | awk '{print $3}' | cut -d':' -f1)
        device=$(echo "$line" | sed 's/.*: //')
        
        case "$class_code" in
            "0300"|"0302"|"0380")
                case "$vendor_id" in
                    "10de") gpu_types["nvidia"]=1 ;;
                    "1002") 
                        gpu_types["amd"]=1 
                        amd_count=$((amd_count + 1))
                        ;;
                    "8086") gpu_types["intel"]=1 ;;
                esac
                
                ${ui.messages.info "Found GPU:"}
                ${ui.tables.keyValue "Device" "$device"}
                ${ui.tables.keyValue "Bus ID" "$bus_id"}
                ${ui.tables.keyValue "Vendor ID" "$vendor_id"}
                ${ui.tables.keyValue "Class Code" "$class_code"}
                ;;
        esac
    done < <(${pkgs.pciutils}/bin/lspci -nn | grep -E "\[0300\]|\[0302\]|\[0380\]")

    echo "AMD GPU count: $amd_count"
    
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

    if [ "$DETECTED" = "none" ]; then
        if command -v ${pkgs.systemd}/bin/systemd-detect-virt &> /dev/null; then
            virt_type=$(${pkgs.systemd}/bin/systemd-detect-virt || echo "none")
            
            if [ "$virt_type" != "none" ]; then
                if ${pkgs.pciutils}/bin/lspci | grep -qi "qxl"; then
                    DETECTED="vm-gpu"
                elif ${pkgs.pciutils}/bin/lspci | grep -qi "virtio"; then
                    DETECTED="vm-gpu"
                else
                    DETECTED="vm-gpu"
                fi
                
                ${ui.messages.info "Virtual Machine: $virt_type"}
                ${ui.messages.info "Virtual Display: $DETECTED"}
            fi
        fi
    fi
    
    if [ ! -f "${hardwareConfigPath}" ]; then
      ${ui.messages.info "hardware-config.nix not found, creating it..."}
      update-hardware-config "${hardwareConfigPath}" "gpu" "$DETECTED"
      ${ui.badges.success "hardware-config.nix created with detected GPU."}
      exit 0
    fi
    
    if ! CONFIGURED=$(grep 'gpu =' "${hardwareConfigPath}" | cut -d'"' -f2); then
      ${ui.messages.warning "Could not find GPU configuration in hardware-config.nix, setting detected GPU..."}
      update-hardware-config "${hardwareConfigPath}" "gpu" "$DETECTED"
      ${ui.badges.success "GPU configuration set to $DETECTED."}
      exit 0
    fi
    
    ${ui.text.subHeader "GPU Configuration:"}
    ${ui.tables.keyValue "Detected" "$DETECTED"}
    ${ui.tables.keyValue "Configured" "$CONFIGURED"}
    
    if [ "$DETECTED" != "$CONFIGURED" ]; then
      ${ui.messages.warning "GPU configuration mismatch! Auto-updating..."}
      ${ui.messages.warning "System configured for $CONFIGURED but detected $DETECTED"}
      
      update-hardware-config "${hardwareConfigPath}" "gpu" "$DETECTED"
      ${ui.badges.success "GPU configuration updated to $DETECTED."}
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
    (cliRegistry.registerCommandsFor "system-checks-gpu" [
      {
        name = "check-gpu";
        domain = "system";
        category = "system-checks";
        internal = true;
        description = "Check GPU configuration before system rebuild";
        script = "${prebuildScript}/bin/prebuild-check-gpu";
        shortHelp = "check-gpu - Verify GPU configuration";
        longHelp = ''
          Check GPU configuration before system rebuild
          
          Checks:
          - Detects installed GPU hardware
          - Compares with configured GPU setting
          - Auto-updates hardware-config.nix if needed
          
          Supports detection of:
          - NVIDIA, AMD, Intel graphics
          - Hybrid configurations
          - Virtual machine graphics
        '';
        interactive = false;
        dependencies = [ "system-checks" ];
      }
      ])
  ];
}
