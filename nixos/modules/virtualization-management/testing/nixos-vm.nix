# development/virtualization/nixos-vm.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.virtualisation.nixos-vm;
in {
  options.virtualisation.nixos-vm = {
    enable = mkEnableOption "NixOS VM for testing";
    
    memory = mkOption {
      type = types.int;
      default = 4096;
      description = "RAM in MB";
    };

    cores = mkOption {
      type = types.int;
      default = 2;
      description = "Number of CPU cores";
    };

    spicePort = mkOption {
      type = types.port;
      default = 5900;
      description = "SPICE display port";
    };
  };

  config = mkIf cfg.enable {
    # QEMU/KVM
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;

    # Packages and tools
    environment.systemPackages = with pkgs; [
      # GUI tools
      virt-manager
      virt-viewer
      
      # SPICE remote display
      spice
      spice-gtk
      spice-protocol
      
      # Virtualization tools
      win-virtio
      OVMF
      
      # VM start script
      (writeShellScriptBin "start-nixos-vm" ''
        ${pkgs.qemu}/bin/qemu-system-x86_64 \
          -enable-kvm \
          -m ${toString cfg.memory} \
          -smp ${toString cfg.cores} \
          -cpu host \
          -vga qxl \
          -spice port=${toString cfg.spicePort},disable-ticketing=on \
          -device virtio-tablet-pci \
          -device virtio-keyboard-pci \
          -drive file=/var/lib/libvirt/images/nixos-test.qcow2,if=virtio \
          -boot d
      '')
    ];

    # Firewall
    networking.firewall.allowedTCPPorts = [ cfg.spicePort ];
  };
}