# development/virtualization.nix
{ config, lib, pkgs, ... }:
{
    imports = [../../../../virtualization-management];

    # Aktiviere VM mit Remote-Zugriff
    virtualisation.management.testing.nixos-vm = {
      enable = true;
      memory = 8192;  # 8GB RAM
      cores = 4;      # 4 Kerne
      remote.enable = true;
    };
    environment.systemPackages = with pkgs; [
      # GUI Tools
      virt-viewer    # SPICE/VNC client
      virt-manager   # Grafische Verwaltung von VMs
      
      # CLI Tools
      qemu          # QEMU selbst
      spice-gtk     # SPICE client libraries
      
      # Netzwerk Tools
      bridge-utils  # Für Netzwerk-Bridges
      wget         # Für ISO Downloads
      
      # Debugging Tools
      socat        # Für QEMU Monitor
      lsof         # Für Port-Debugging
    ];
}