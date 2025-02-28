#!/usr/bin/env bash

check_gpu_info() {
    log_section "Detecting GPU Configuration"
    
    # Initialize variables
    local gpu_config="generic"
    declare -A gpu_types
    local primary_bus_id=""
    local secondary_bus_id=""
    
    # Physical hardware detection first
    while IFS= read -r line; do
        local bus_id=$(echo "$line" | cut -d' ' -f1)
        local vendor_id=$(lspci -n -s "$bus_id" | awk '{print $3}' | cut -d':' -f1)
        local device=$(echo "$line" | sed 's/.*: //')
        
        case "$vendor_id" in
            "10de")  # NVIDIA
                gpu_types["nvidia"]=1
                [ -z "$primary_bus_id" ] && primary_bus_id="$bus_id"
                ;;
            "1002")  # AMD
                gpu_types["amd"]=1
                [ -z "$primary_bus_id" ] && primary_bus_id="$bus_id"
                ;;
            "8086")  # Intel
                gpu_types["intel"]=1
                [ -z "$secondary_bus_id" ] && secondary_bus_id="$bus_id"
                ;;
        esac

        if [ "${DEBUG:-false}" = true ]; then
            log_debug "Found GPU:"
            log_debug "  Device: $device"
            log_debug "  Bus ID: $bus_id"
            log_debug "  Vendor ID: $vendor_id"
        fi
    done < <(lspci | grep -E "VGA|3D|Display")

    # Determine GPU configuration
    if [ "${gpu_types["nvidia"]-0}" -eq 1 ] && [ "${gpu_types["intel"]-0}" -eq 1 ]; then
        gpu_config="nvidia-intel"
    elif [ "${gpu_types["amd"]-0}" -eq 1 ] && [ "${gpu_types["intel"]-0}" -eq 1 ]; then
        gpu_config="amd-intel"
    elif [ "${gpu_types["nvidia"]-0}" -eq 1 ]; then
        gpu_config="nvidia"
    elif [ "${gpu_types["amd"]-0}" -eq 1 ]; then
        gpu_config="amd"
    elif [ "${gpu_types["intel"]-0}" -eq 1 ]; then
        gpu_config="intel"
    fi

    # Only check for VM if no physical GPU was detected
    if [ "$gpu_config" = "generic" ] && command -v systemd-detect-virt &>/dev/null; then
        local virt_type=$(systemd-detect-virt || echo "none")
        
        if [ "$virt_type" != "none" ]; then
            log_info "Virtual Machine detected: ${virt_type}"
            
            # Check for virtual GPU types
            if lspci | grep -qi "qxl"; then
                gpu_config="qxl-virtual"
                primary_bus_id=$(lspci | grep -i "qxl" | cut -d' ' -f1)
            elif lspci | grep -qi "virtio"; then
                gpu_config="virtio-virtual"
                primary_bus_id=$(lspci | grep -i "virtio" | cut -d' ' -f1)
            else
                gpu_config="basic-virtual"
                primary_bus_id=$(lspci | grep -E "VGA|3D|Display" | cut -d' ' -f1)
            fi
        fi
    fi

    log_info "GPU Configuration:"
    log_info "  Type: ${gpu_config}"
    log_info "  Primary GPU Bus ID: ${primary_bus_id}"
    [ -n "$secondary_bus_id" ] && log_info "  Secondary GPU Bus ID: ${secondary_bus_id}"

    # Export variables
    export GPU_CONFIG="$gpu_config"
    export GPU_PRIMARY_BUS="$primary_bus_id"
    export GPU_SECONDARY_BUS="$secondary_bus_id"
    
    return 0
}

# Export functions
export -f check_gpu_info