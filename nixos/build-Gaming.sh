#!/usr/bin/env bash
set -e  # Exit bei Fehlern

echo "Copying configuration..."
sudo cp -r /home/fr4iser/.local/nixos/* /etc/nixos/

echo "Building system..."
sudo nixos-rebuild switch --flake /etc/nixos#Gaming

echo "Cleaning up..."
rm -rf /home/fr4iser/.local/nixos

echo "Build complete!"
