#!/usr/bin/env bash



log_section "CPU Detection"

get_cpu_info() {
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
        features=$(grep "flags" /proc/cpuinfo | head -n1 | cut -d: -f2-)
        if echo "$features" | grep -q "vmx"; then
            virtualization="intel"
        elif echo "$features" | grep -q "svm"; then
            virtualization="amd"
        fi

        # Ausgabe für Benutzer
        log_info "CPU Information:"
        log_info "  Vendor: ${CYAN}${vendor}${NC}"
        log_info "  Virtualization: ${CYAN}${virtualization}${NC}"
    else
        log_error "Could not read CPU information"
        return 1
    fi

    # Variablen für weitere Verarbeitung
    export CPU_VENDOR="$vendor"
    export CPU_VIRTUALIZATION="$virtualization"
}

# Ausführen
get_cpu_info