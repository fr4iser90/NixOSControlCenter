#!/usr/bin/env bash

check_bootloader() {
    log_section "Detecting Boot Configuration"

    local boot_type="unknown"

    # Boot Mode prüfen
    if [ -d "/sys/firmware/efi" ]; then
        boot_type="systemd-boot"  # UEFI -> systemd-boot
    else
        boot_type="grub"         # Legacy -> GRUB
    fi

    # Ausgabe
    log_info "Boot Configuration:"
    log_info "  Type: ${boot_type}"

    # Export für weitere Verarbeitung
    export BOOT_TYPE="$boot_type"
    
    return 0
}

# Export functions
export -f check_bootloader