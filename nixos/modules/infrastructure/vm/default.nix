{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

with lib;

let
  cfg = getModuleConfig "vm";
  stateDir = cfg.stateDir;
in {
  _module.metadata = {
    role = "optional";
    name = "vm";
    description = "Virtual machine management and orchestration";
    category = "infrastructure";
    subcategory = "virtualization";
    stability = "stable";
  };

  imports = if cfg.enable or false then [
    ./options.nix
    (import ./testing { inherit config lib pkgs; })
  ] else [];

  config = mkMerge [
    {
      modules.infrastructure.vm.enable = mkDefault (cfg.enable or false);
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
    features.infrastructure.vm.storage.enable = true;

    # Register VM category
    })
  ];
}