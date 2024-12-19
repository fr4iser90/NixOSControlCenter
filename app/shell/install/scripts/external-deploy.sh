#!/usr/bin/env bash

nixos_dir="$HOME/.local/nixos"

echo "Copying configuration to /etc/nixos..."
sudo cp -r "$nixos_dir"/* /etc/nixos/

echo "Building system..."
sudo nixos-rebuild switch

echo "Cleaning up..."
rm -rf "$nixos_dir"

echo "Build complete!"