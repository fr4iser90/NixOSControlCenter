#!/usr/bin/env bash

log_section "Detecting GPU Configuration"

get_gpu_info() {
    local gpu_config="unknown"
    local found_gpus=()
    local primary_bus_id=""
    local secondary_bus_id=""
    local has_dgpu=false
    local has_igpu=false

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
        log_info "  Type: ${CYAN}${gpu_config}${NC}"
        log_info "  Primary GPU Bus ID: ${CYAN}${primary_bus_id}${NC}"
        [ -n "$secondary_bus_id" ] && log_info "  Secondary GPU Bus ID: ${CYAN}${secondary_bus_id}${NC}"
        
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
}

# Ausführen
get_gpu_info