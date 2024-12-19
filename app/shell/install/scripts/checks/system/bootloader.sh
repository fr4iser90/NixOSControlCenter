#!/usr/bin/env bash

log_section "Detecting Boot Configuration"

get_boot_info() {
    local boot_type="unknown"

    # Boot Mode prüfen
    if [ -d "/sys/firmware/efi" ]; then
        boot_type="systemd-boot"  # UEFI -> systemd-boot
    else
        boot_type="grub"         # Legacy -> GRUB
    fi

    # Ausgabe
    log_info "Boot Configuration:"
    log_info "  Type: ${CYAN}${boot_type}${NC}"

    # Export für weitere Verarbeitung
    export BOOT_TYPE="$boot_type"
}

# Ausführen
get_boot_info