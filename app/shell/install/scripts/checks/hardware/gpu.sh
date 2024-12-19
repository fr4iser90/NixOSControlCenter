#!/usr/bin/env bash


log_section "Detecting GPU Configuration"

# Check for GPUs using lspci
log_info "GPU Hardware Detection:"
if command -v lspci &> /dev/null; then
    while IFS= read -r line; do
        # Wichtige Build-Informationen
        bus_id=$(echo "$line" | cut -d' ' -f1)
        vendor_id=$(lspci -n -s "$bus_id" | awk '{print $3}' | cut -d':' -f1)
        device_id=$(lspci -n -s "$bus_id" | awk '{print $3}' | cut -d':' -f2)
        gpu_name=$(echo "$line" | sed 's/.*: //')
        
        echo -e "  Device   : ${CYAN}${gpu_name}${NC}"
        echo -e "  Bus ID   : ${GRAY}${bus_id}${NC}"
        echo -e "  Vendor ID: ${GRAY}${vendor_id}${NC}"
        echo -e "  Device ID: ${GRAY}${device_id}${NC}"
        
        # Kernel Driver
        if [ -d "/sys/bus/pci/devices/0000:${bus_id}" ]; then
            driver=$(readlink "/sys/bus/pci/devices/0000:${bus_id}/driver" 2>/dev/null | xargs basename 2>/dev/null)
            [ -n "$driver" ] && echo -e "  Driver   : ${GRAY}${driver}${NC}"
        fi
        
        echo ""
    done < <(lspci | grep -E "VGA|3D|Display")
else
    echo -e "  ${RED}Could not detect PCI devices${NC}"
fi