{ config, lib, pkgs, ... }:

with lib;

let
  stateDir = "/var/lib/virt";
in {
  imports = [
    (import ./testing { inherit config lib pkgs; })
  ];

  options.features.vm-manager = {
    enable = mkEnableOption "VM Manager";
    storage.enable = mkEnableOption "Storage Management for VMs";
    stateDir = mkOption {
      type = types.path;
      default = stateDir;
      description = "Base directory for virtualization state";
    };
  };

  config = {
    # Base requirements
    virtualisation = {
      libvirtd.enable = true;
  #    libvirtd.qemu.enable = true;
  #    libvirtd.qemu.package = pkgs.qemu_kvm;
      libvirtd.allowedBridges = [ "virbr0" ];
      spiceUSBRedirection.enable = true;
    };


    programs.virt-manager.enable = true;

    # Base packages
    environment.systemPackages = with pkgs; [
      qemu
      virt-manager
      spice
      spice-gtk
      spice-protocol
 #     OVMF
      swtpm
    ];

    # Base directory structure
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0755 root root -"
      "d ${stateDir}/images 0775 root libvirt -"
      "d ${stateDir}/testing 0775 root libvirt -"
    ];

    # Enable components
    features.vm-manager.storage.enable = true;

    # Register VM category
    
  };
}