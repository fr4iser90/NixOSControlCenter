{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.virtualisation.management;
in {

  options.virtualisation.management = {
    enable = mkEnableOption "Virtualization Management";
    
    stateDir = mkOption {
      type = types.path;
      default = "/var/lib/virt";
      description = "Base directory for virtualization state";
    };
  };

  config = mkIf cfg.enable {
    # Base requirements
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;

    # Base packages
    environment.systemPackages = with pkgs; [
      virt-manager
      qemu
      spice
      spice-gtk
      spice-protocol
      win-virtio
      OVMF
    ];

    # Base directory structure
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 root root -"
      "d ${cfg.stateDir}/images 0775 root libvirt -"
      "d ${cfg.stateDir}/testing 0775 root libvirt -"
    ];

    assertions = [
      {
        assertion = config.virtualisation.management.storage.enable;
        message = "Storage management must be enabled for virtualization management";
      }
    ];
  };
}