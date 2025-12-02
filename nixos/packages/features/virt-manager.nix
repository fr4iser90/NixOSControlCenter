# virt-manager.nix
# Virtualization Management GUI
# Requires: qemu-vm feature

{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # GUI Tools
    virt-viewer    # SPICE/VNC clients for VM display
    virt-manager   # Graphical interface to manage virtual machines
  ];
}

