#!/usr/bin/env bash


log_section "Detecting Boot Configuration"

# UEFI Variables
log_info "UEFI Variables:"
efibootmgr -v | grep -E "BootCurrent|Timeout|BootOrder|Boot[0-9]"

# Secure Boot Status
if mokutil --sb-state &>/dev/null; then
    log_info "Secure Boot: ${GREEN}Enabled${NC}"
else
    log_info "Secure Boot: ${RED}Disabled${NC}"
fi

# Boot Mode
if [ -d "/sys/firmware/efi" ]; then
    log_info "Boot Mode: ${GREEN}UEFI${NC}"
else
    log_info "Boot Mode: ${YELLOW}Legacy BIOS${NC}"
fi

# Partition Table
log_info "Partition Table:"
lsblk --output NAME,SIZE,FSTYPE,MOUNTPOINTS | grep -E "/$|/boot|SWAP" | sed 's/^/  /'

# Boot Partition
log_info "Boot Partition Details:"
boot_info=$(findmnt /boot -n -o SOURCE,FSTYPE,OPTIONS)
source=$(echo "$boot_info" | awk '{print $1}')
fstype=$(echo "$boot_info" | awk '{print $2}')
echo -e "  Source: ${CYAN}$source${NC}"
echo -e "  Type  : ${CYAN}$fstype${NC}"

# Kernel Parameters
log_info "Current Kernel Parameters:"
cmdline=$(cat /proc/cmdline | tr -d '\n' | sed 's/\\//g' | sed 's/EFInixos/EFI\/nixos\//g')
echo -e "  ${GRAY}$cmdline${NC}"

# List installed kernels (only show latest 5 with version extraction)
log_info "Recent Kernel Generations (latest 5):"
for conf in $(ls -t /boot/loader/entries/nixos-generation-*.conf | head -n 5); do
    gen=$(echo "$conf" | grep -o '[0-9]\+\.conf$' | cut -d. -f1)
    version=$(grep "linux" "$conf" | grep -o 'linux-[0-9.]\+' | head -n1)
    date=$(stat -c %y "$conf" | cut -d. -f1)
    echo -e "  ${CYAN}Generation ${gen}${NC} - Kernel ${GREEN}${version:-unknown}${NC} (${GRAY}$date${NC})"
done