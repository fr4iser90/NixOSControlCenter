# development/virtualization.nix
{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # GUI Tools
    virt-viewer    # SPICE/VNC clients for VM display
    virt-manager   # Graphical interface to manage virtual machines

    # CLI Tools
    qemu          # Full virtualization solution
    spice-vdagent # SPICE client for better integration
    spice-gtk     # SPICE client libraries for graphical interaction

    # Networking Tools
    bridge-utils  # Tools for managing network bridges
    wget          # Downloading ISO images or other resources

    # Debugging Tools
    socat         # Multipurpose relay for QEMU monitor access
    lsof          # Debugging open files and ports
  ];
}
