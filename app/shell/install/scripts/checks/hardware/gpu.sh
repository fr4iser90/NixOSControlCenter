#!/usr/bin/env bash

check_gpu_info() {
    log_section "Detecting GPU Configuration"
    
    local gpu_config="unknown"
    local found_gpus=()
    local primary_bus_id=""
    local secondary_bus_id=""
    local has_dgpu=false
    local has_igpu=false
    
    # First check if we're running in a VM
    if command -v systemd-detect-virt &>/dev/null; then
        local virt_type=$(systemd-detect-virt)
        if [ -n "$virt_type" ]; then
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

            log_info "GPU Configuration:"
            log_info "  Type: ${gpu_config}"
            log_info "  Primary GPU Bus ID: ${primary_bus_id}"
            
            # Export variables and return early for VMs
            export GPU_CONFIG="$gpu_config"
            export GPU_PRIMARY_BUS="$primary_bus_id"
            return 0
        fi
    fi

    if command -v lspci &> /dev/null; then
        while IFS= read -r line; do
            local bus_id=$(echo "$line" | cut -d' ' -f1)
            local vendor_id=$(lspci -n -s "$bus_id" | awk '{print $3}' | cut -d':' -f1)
            local gpu_name=$(echo "$line" | sed 's/.*: //')
            
            # GPU-Typ und Rolle bestimmen
            case "$vendor_id" in
                "1002")  # AMD
                    if echo "$gpu_name" | grep -qi "radeon\|graphics"; then
                        found_gpus+=("amd-dgpu")
                        has_dgpu=true
                    else
                        found_gpus+=("amd-igpu")
                        has_igpu=true
                    fi
                    ;;
                "10de")  # NVIDIA
                    found_gpus+=("nvidia")
                    has_dgpu=true
                    ;;
                "8086")  # Intel
                    found_gpus+=("intel-igpu")
                    has_igpu=true
                    ;;
            esac

            # Bus IDs setzen
            if [ "$has_dgpu" = true ] && [ -z "$primary_bus_id" ]; then
                primary_bus_id="$bus_id"
            elif [ "$has_igpu" = true ] && [ -z "$secondary_bus_id" ]; then
                secondary_bus_id="$bus_id"
            fi
        done < <(lspci | grep -E "VGA|3D|Display")

        # GPU-Konfiguration bestimmen
        if [ ${#found_gpus[@]} -eq 1 ]; then
            # Einzelne GPU
            case "${found_gpus[0]}" in
                "amd-dgpu") gpu_config="amd" ;;
                "amd-igpu") gpu_config="amd-integrated" ;;
                "nvidia") gpu_config="nvidia" ;;
                "intel-igpu") gpu_config="intel" ;;
            esac
        elif [ ${#found_gpus[@]} -ge 2 ]; then
            # Multiple GPUs - Sortiere dGPU vor iGPU
            if echo "${found_gpus[*]}" | grep -q "nvidia"; then
                if echo "${found_gpus[*]}" | grep -q "intel-igpu"; then
                    gpu_config="nvidia-intel"
                elif echo "${found_gpus[*]}" | grep -q "amd-igpu"; then
                    gpu_config="nvidia-amd"
                fi
            elif echo "${found_gpus[*]}" | grep -q "amd-dgpu"; then
                if echo "${found_gpus[*]}" | grep -q "intel-igpu"; then
                    gpu_config="amd-intel"
                elif echo "${found_gpus[*]}" | grep -q "amd-igpu"; then
                    gpu_config="amd-integrated"
                fi
            fi
        fi

        log_info "GPU Configuration:"
        log_info "  Type: ${gpu_config}"
        log_info "  Primary GPU Bus ID: ${primary_bus_id}"
        [ -n "$secondary_bus_id" ] && log_info "  Secondary GPU Bus ID: ${secondary_bus_id}"
        
        if [ "${DEBUG:-false}" = true ]; then
            log_debug "Found GPUs: ${found_gpus[*]}"
            log_debug "Has dGPU: $has_dgpu"
            log_debug "Has iGPU: $has_igpu"
        fi
    else
        log_error "Could not detect PCI devices"
        return 1
    fi

    # Variablen für weitere Verarbeitung
    export GPU_CONFIG="$gpu_config"
    export GPU_PRIMARY_BUS="$primary_bus_id"
    export GPU_SECONDARY_BUS="$secondary_bus_id"
    
    return 0
}

# Export functions
export -f check_gpu_info