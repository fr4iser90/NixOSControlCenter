#!/usr/bin/env bash

check_hardware_config() {
  set -euo pipefail

  # Auto-detect main disk (exclude loop, rom, removable)
  detect_disk() {
    lsblk -ndo NAME,TYPE,SIZE,RM | awk '$2=="disk" && $4==0 {print $1, $3}' | sort -k2 -hr | head -n1 | awk '{print "/dev/"$1}'
  }

  DISK="$(detect_disk)"
  if [ -z "$DISK" ]; then
    echo "No suitable disk found."
    exit 1
  fi

  BOOT_PART="${DISK}p1"
  ROOT_PART="${DISK}p2"

  echo "Detected disk: $DISK"

  # 1. Check for hardware-configuration.nix
  if [ -f /mnt/etc/nixos/hardware-configuration.nix ] || [ -f /etc/nixos/hardware-configuration.nix ]; then
    echo "hardware-configuration.nix found. Exiting."
    return 0
  fi

  # 2. Check if partitions exist
  if ! lsblk -f | grep -q "${BOOT_PART}"; then
    echo "Partitioning disk $DISK..."
    parted -s "$DISK" mklabel gpt
    parted -s "$DISK" mkpart ESP fat32 1MiB 1025MiB
    parted -s "$DISK" set 1 esp on
    parted -s "$DISK" mkpart primary ext4 1025MiB 100%
    mkfs.fat -F 32 "$BOOT_PART"
    mkfs.ext4 -L nixos "$ROOT_PART"
  else
    echo "Partitions already exist on $DISK."
  fi

  # 3. Mount partitions
  if ! mount | grep -q "/mnt "; then
    mount "$ROOT_PART" /mnt
  fi
  mkdir -p /mnt/boot
  if ! mount | grep -q "/mnt/boot"; then
    mount "$BOOT_PART" /mnt/boot
  fi

  # 4. Generate hardware config
  if [ ! -f /mnt/etc/nixos/hardware-configuration.nix ]; then
    nixos-generate-config --root /mnt
  fi

  # 5. Copy config to /etc/nixos/ if possible
  if [ -f /mnt/etc/nixos/hardware-configuration.nix ]; then
    mkdir -p /etc/nixos
    cp /mnt/etc/nixos/hardware-configuration.nix /etc/nixos/
    echo "hardware-configuration.nix copied to /etc/nixos/"
  else
    echo "hardware-configuration.nix not found after generation."
    exit 2
  fi

  echo "Hardware configuration and partitioning complete."
}

export -f check_hardware_config
