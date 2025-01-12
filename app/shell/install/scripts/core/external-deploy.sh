#!/usr/bin/env bash
set -euo pipefail

# Verzeichnis
nixos_dir="$HOME/.local/nixos"

# Prüfe ob Verzeichnis existiert
if [[ ! -d "$nixos_dir" ]]; then
    echo "Error: Configuration directory not found: $nixos_dir"
    exit 1
fi

# Prüfe sudo-Rechte
if ! sudo -n true 2>/dev/null; then
    echo "Error: This script requires sudo privileges"
    exit 1
fi

echo "Copying configuration to /etc/nixos..."
sudo cp -r "$nixos_dir"/* /etc/nixos/

echo "Building system..."
sudo nixos-rebuild switch

echo "Cleaning up..."
rm -rf "$nixos_dir"

echo "Build complete!"