{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.virtualisation.management.testing.nixos-vm;
  libVM = import ../lib { inherit lib pkgs; };
in {
  options.virtualisation.management.testing.nixos-vm = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "NixOS VM for testing";
    };

    distro = mkOption {
      type = types.enum (attrNames libVM.distros);
      default = "nixos";
      description = "Linux distribution to use";
    };

    variant = mkOption {
      type = types.str;
      default = "plasma5";
      description = "Distribution variant (e.g., plasma5, gnome, desktop)";
    };

    version = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Distribution version (null for default)";
    };

    memory = mkOption {
      type = types.int;
      default = 8192;
      description = "RAM in MB";
    };

    cores = mkOption {
      type = types.int;
      default = 4;
      description = "CPU cores";
    };

    remote = {
      enable = mkEnableOption "Remote access";
      displayPort = mkOption {
        type = types.port;
        default = 5900;
        description = "SPICE display port";
      };
    };

    image = {
      path = mkOption {
        type = types.path;
        default = "/var/lib/virt/testing/nixos-test.qcow2";
        description = "Path to VM image";
      };
      size = mkOption {
        type = types.int;
        default = 100;
        description = "Image size in GB";
      };
    };
  };

  config = mkIf cfg.enable {
    # Aktiviere automatisch alle Abhängigkeiten
    virtualisation = {
      libvirtd.enable = true;
      spiceUSBRedirection.enable = true;
    };
    programs.virt-manager.enable = true;

    # Required packages
    environment.systemPackages = with pkgs; [
      # GUI tools
      virt-manager
      virt-viewer
      
      # SPICE remote display
      spice
      spice-gtk
      spice-protocol
      
      # Virtualization tools
      qemu
      win-virtio
      OVMF
      
      # VM management script
      (writeShellScriptBin "nixos-test-vm" ''
        set -e
        
        ${libVM.mkVmScript {
          name = "nixos-test";
          memory = cfg.memory;
          cores = cfg.cores;
          image = cfg.image;
          distro = cfg.distro;
          variant = cfg.variant;
          version = cfg.version;
        }}

        # Main
        prepare_ovmf
        create_disk
        iso_path=$(download_iso)
        start_vm "$iso_path"
      '')
    ];

    # Base directory structure with correct permissions
    systemd.tmpfiles.rules = [
      "d /var/lib/virt 0755 root root -"
      "d /var/lib/virt/testing 0775 root libvirt -"
      "d /var/lib/virt/testing/iso 0775 root libvirt -"
      "d /var/lib/virt/testing/vars 0775 root libvirt -"  # Für OVMF_VARS
    ];

    # Network access
    networking.firewall = mkIf cfg.remote.enable {
      allowedTCPPorts = [ cfg.remote.displayPort ];
    };

    # User permissions
    users.groups.libvirt = {};
    security.wrappers.qemu-bridge-helper = mkForce {
      source = "${pkgs.qemu}/libexec/qemu-bridge-helper";
      owner = "root";
      group = "libvirt";
      setuid = true;
      permissions = "u+rx,g+x";
    };
  };
}