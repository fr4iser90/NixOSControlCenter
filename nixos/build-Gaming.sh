#!/usr/bin/env bash
set -e

log_info "Copying configuration..."
sudo cp -r /home/fr4iser/.local/nixos/* /etc/nixos/

log_info "Building system..."
sudo nixos-rebuild switch --flake /etc/nixos#Gaming

log_info "Cleaning up..."
rm -rf /home/fr4iser/.local/nixos

log_success "Build complete!"
