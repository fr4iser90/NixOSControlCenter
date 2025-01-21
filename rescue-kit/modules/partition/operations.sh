#!/bin/bash

# Run all checks
run_all_checks_handler() {
    echo "Running system checks..."
    
    
    if ! detect_partitions; then
        return 1
    fi
    
    if ! verify_partitions; then
        return 1
    fi
    
    if ! list_usb_devices; then
        return 1
    fi
    
    echo "All checks completed successfully"
    return 0
}


# Detect partitions and categorize
detect_partitions_handler() {
    echo "Detecting partitions..."

    # Alle Partitionen abrufen
    local all_partitions=$(lsblk -o NAME,SIZE,FSTYPE,TRAN,MOUNTPOINT -p -n | grep -Ev 'iso9660|loop|zram|swap')
    if [ -z "$all_partitions" ]; then
        echo "Error: No valid partitions found."
        return 1
    fi

    echo "All detected partitions:"
    echo "$all_partitions"
    echo ""

    # Root-Kandidaten: NVMe/SATA mit gängigen Dateisystemen
    local root_candidates=$(echo "$all_partitions" | grep -E 'ext4|xfs|btrfs' | grep -E 'nvme|sata' | sort -k2 -nr)

    # Boot-Kandidaten: FAT-basierte Partitionen mit Mindestgröße 250 MB
    local boot_candidates=$(echo "$all_partitions" | grep -E 'vfat|fat32' | awk '{if ($2 >= 250 * 1024 * 1024) print}' | sort -k2 -nr)

    # Backup-Kandidaten: USB-Partitionen
    local backup_candidates=$(echo "$all_partitions" | grep 'usb' | sort -k2 -nr)

    # Ergebnisse speichern
    echo "$root_candidates" > /tmp/root_candidates
    echo "$boot_candidates" > /tmp/boot_candidates
    echo "$backup_candidates" > /tmp/backup_candidates

    echo "Root Partition Candidates:"
    echo "$root_candidates"
    echo ""
    echo "Boot Partition Candidates:"
    echo "$boot_candidates"
    echo ""
    echo "Backup Partition Candidates:"
    echo "$backup_candidates"
    echo ""

    echo "Partition detection completed."
    return 0
}




# Enhanced Select a partition from a given list
select_partition_handler() {
    local prompt="$1"
    local candidates_file="$2"

    if [ ! -s "$candidates_file" ]; then
        echo "No valid $prompt candidates found."
        return 1
    fi

    # Zeige verfügbare Partitionen an
    echo "Available $prompt partitions:"
    cat "$candidates_file"
    echo ""

    # Automatische Vorschläge anzeigen
    local default=$(head -n1 "$candidates_file" | awk '{print $1}')
    echo "Suggested $prompt partition: $default"

    # Benutzer zur Eingabe auffordern
    echo ""
    read -p "Enter your choice for $prompt partition (or press Enter to use the suggestion): " selected

    # Verwende Vorschlag, wenn keine Eingabe erfolgt
    if [ -z "$selected" ]; then
        selected="$default"
        echo "Defaulting to: $selected"
    fi

    # Validierung der Auswahl
    if grep -q "^$selected" "$candidates_file"; then
        echo "Selected $prompt partition: $selected"
        echo "$selected"
        return 0
    else
        echo "Invalid choice: $selected"
        return 1
    fi
}

# High-level function to suggest and select partitions
suggest_partitions_handler() {
    echo ""
    echo "Partition Suggestions:"

    echo "Root Partition Candidates:"
    cat /tmp/root_candidates
    echo ""

    echo "Boot Partition Candidates:"
    cat /tmp/boot_candidates
    echo ""

    echo "Backup Partition Candidates:"
    cat /tmp/backup_candidates
    echo ""

    # Auswahl treffen
    ROOT_PART=$(select_partition_handler "root" "/tmp/root_candidates") || return 1
    BOOT_PART=$(select_partition_handler "boot" "/tmp/boot_candidates") || return 1
    BACKUP_PART=$(select_partition_handler "backup" "/tmp/backup_candidates")

    # Endgültige Auswahl anzeigen
    echo ""
    echo "Using the following partitions:"
    echo "Root Partition: $ROOT_PART"
    echo "Boot Partition: $BOOT_PART"
    echo "Backup Partition: ${BACKUP_PART:-No backup selected}"
    sleep 5.0

    export ROOT_PART BOOT_PART BACKUP_PART
    return 0
}

# List available USB devices with improved error handling
list_usb_devices_handler() {
    echo "Listing USB devices..."
    list_live_usb_devices_handler || { return 1; }
    list_backup_usb_devices_handler || { return 1; }
    checks_menu  # Zurück ins Menü nach Abschluss
}


# List available Backup USB devices
list_backup_usb_devices_handler() {
    echo "Listing Backup USB devices..."
    
    # Get USB devices using lsblk, excluding ISO filesystems
    local backup_usb_devices=$(lsblk -d -o NAME,TRAN,SIZE,MODEL,MOUNTPOINT,FSTYPE | grep usb | grep -v 'iso')
    
    echo "WARNING: Live USB systems should not be used as backup targets"
    
    if [ -z "$backup_usb_devices" ]; then
        echo "No USB devices found for backup"
        sleep 1.0
    fi
    
    echo "Available Backup USB devices:"
    echo "$backup_usb_devices"
    return 0
}

# List available Live USB devices
list_live_usb_devices_handler() {
    echo "Listing Live USB devices..."
    
    # Get USB devices using lsblk, including ISO filesystems
    local live_usb_devices=$(lsblk -d -o NAME,TRAN,SIZE,MODEL,MOUNTPOINT,FSTYPE | grep usb | grep 'iso')
    
    if [ -z "$live_usb_devices" ]; then
        echo "No Live USB devices found"
        sleep 1.0
    fi
    
    echo "Available Live USB devices:"
    echo "$live_usb_devices"
    return 0
}

# Verify system partitions
verify_partitions_handler() {
    echo "Verifying partitions..."
    
    # Check if root partition exists
    if [ ! -e "$ROOT_PART" ]; then
        echo "Error: Root partition $ROOT_PART not found"
        return 1
    fi
    
    # Check if boot partition exists (if specified)
    if [ -n "$BOOT_PART" ] && [ ! -e "$BOOT_PART" ]; then
        echo "Error: Boot partition $BOOT_PART not found"
        return 1
    fi
    
    echo "Partitions verified successfully"
    return 0
}

# Verify system requirements
verify_system_requirements_handler() {
    echo "Verifying system requirements..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo "Error: Script must be run as root"
        return 1
    fi
    
    # Check for required commands
    local required_commands=("lsblk" "mount" "umount" "chroot" "nixos-install")
    for cmd in "${required_commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            echo "Error: Required command '$cmd' not found"
            return 1
        fi
    done
    
    echo "System requirements verified"
    return 0
}

# Set up bind mounts for chroot
setup_bind_mounts_handler() {
    echo "Setting up bind mounts..."
    
    local required_mounts=("/proc" "/sys" "/dev" "/run")
    
    for mount_point in "${required_mounts[@]}"; do
        if [ -d "$mount_point" ]; then
            mkdir -p $MOUNT_DIR$mount_point
            mount --bind $mount_point $MOUNT_DIR$mount_point || { 
                echo "Failed to bind mount $mount_point"; 
                return 1
            }
        else
            echo "Warning: $mount_point does not exist"
        fi
    done
    
    echo "Bind mounts set up successfully"
    return 0
}

# Main bind mounts function
bind_mounts() {
    if ! setup_bind_mounts; then
        echo "Error: Failed to set up bind mounts"
        return 1
    fi
    return 0
}


# Mount partitions and set up chroot environment
mount_partitions_handler() {
    echo "Mounting partitions..."

    # Create mount directories if they don't exist
    mkdir -p /mnt || { echo "Failed to create /mnt directory"; return 1; }
    mkdir -p /mnt/boot || { echo "Failed to create /mnt/boot directory"; return 1; }
    mkdir -p /mnt/backup || { echo "Failed to create /mnt/backup directory"; return 1; }

    # Überprüfen ob Partitionen gesetzt sind
    if [ -z "$ROOT_PART" ] || [ -z "$BOOT_PART" ] || [ -z "$BACKUP_PART" ]; then
        echo "Error: Required partitions are missing."
        return 1
    fi

    # Partitionen mounten
    if mount "$ROOT_PART" /mnt; then
        echo "Root partition mounted successfully."
    else
        echo "Failed to mount root partition."
        return 1
    fi

    if mount "$BOOT_PART" /mnt/boot; then
        echo "Boot partition mounted successfully."
    else
        echo "Failed to mount boot partition."
        return 1
    fi

    if mount "$BACKUP_PART" /mnt/backup; then
        echo "Backup partition mounted successfully."
    else
        echo "Failed to mount backup partition."
        return 1
    fi

    return 0
}

# Check if partitions are mounted
is_mounted() {
    # Ensure MOUNT_DIR is available
    if [[ -z "$MOUNT_DIR" ]]; then
        echo "Error: MOUNT_DIR is not set"
        return 1
    fi
    
    if mount | grep -q "$MOUNT_DIR"; then
        return 0
    else
        return 1
    fi
}


# Unmount all partitions and bind mounts
unmount_all() {
    echo "Unmounting all partitions..."
    
    # Unmount bind mounts first
    local mounted_points=($(grep $MOUNT_DIR /proc/mounts | awk '{print $2}' | sort -r))
    
    for point in "${mounted_points[@]}"; do
        umount $point || echo "Warning: Failed to unmount $point"
    done
    
    # Finally unmount root
    umount $MOUNT_DIR || echo "Warning: Failed to unmount root partition"
    
    echo "Unmounting complete"
}
