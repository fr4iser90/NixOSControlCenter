# Migrated from lib/install/bootloader.sh — body via fromJSON (Nix-safe).
{ pkgs }:
pkgs.writeText "bootloader.sh" (builtins.fromJSON ''
"#!/usr/bin/env bash\n\ncheck_bootloader() {\n    log_section \"Detecting Boot Configuration\"\n\n    local boot_type=\"unknown\"\n\n    # Boot Mode pr\u00fcfen\n    if [ -d \"/sys/firmware/efi\" ]; then\n        boot_type=\"systemd-boot\"  # UEFI -> systemd-boot\n    else\n        boot_type=\"grub\"         # Legacy -> GRUB\n    fi\n\n    # Ausgabe\n    log_info \"Boot Configuration:\"\n    log_info \"  Type: \u0024{boot_type}\"\n\n    # Export f\u00fcr weitere Verarbeitung\n    export BOOT_TYPE=\"\u0024boot_type\"\n    \n    return 0\n}\n\n# Export functions\nexport -f check_bootloader"
'')
