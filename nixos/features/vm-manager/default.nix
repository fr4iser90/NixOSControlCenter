{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.features.vm-manager;
  stateDir = cfg.stateDir;
in {
  imports = [
    ./options.nix
    (import ./testing { inherit config lib pkgs; })
  ];

  config = mkMerge [
    {
      features.vm-manager.enable = mkDefault (systemConfig.features.vm-manager or false);
    }
    (mkIf cfg.enable {
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
    })
  ];
}