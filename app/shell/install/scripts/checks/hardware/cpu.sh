#!/usr/bin/env bash

check_cpu_info() {
    log_section "CPU Detection"
    
    local vendor="unknown"
    local model_name
    local virtualization="none"

    if [ -f "/proc/cpuinfo" ]; then
        # CPU Model Name holen
        model_name=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2- | sed 's/^[ \t]*//')
        
        # Vendor bestimmen
        if echo "$model_name" | grep -qi "intel"; then
            vendor="intel"
        elif echo "$model_name" | grep -qi "amd"; then
            vendor="amd"
        fi

        # Virtualisierung prüfen
        features=$(grep "flags" /proc/cpuinfo | head -n1 | cut -d: -f2- || true)
        
        if echo "$features" | grep -q "vmx"; then
            virtualization="intel"
        elif echo "$features" | grep -q "svm"; then
            virtualization="amd"
        fi

        # Ausgabe für Benutzer
        log_info "CPU Information:"
        log_info "  Vendor: $vendor"
        log_info "  Virtualization: $virtualization"
    else
        log_error "Could not read CPU information"
        return 1
    fi

    # Variablen für weitere Verarbeitung
    export CPU_VENDOR="$vendor"
    export CPU_VIRTUALIZATION="$virtualization"
    
    return 0
}

# Export functions
export -f check_cpu_info

# Check script execution
check_script_execution "COLORS_IMPORTED" "LOGGING_IMPORTED"
