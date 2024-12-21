{ config, lib, pkgs, cliTools, ... }:

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
        default = "/var/lib/virt/testing/images/nixos-test.qcow2";
        description = "Path to VM image";
      };
      size = mkOption {
        type = types.int;
        default = 100;
        description = "Image size in GB";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Basis-Konfiguration ohne CLI-Tools
      virtualisation = {
        libvirtd.enable = true;
        spiceUSBRedirection.enable = true;
      };
      programs.virt-manager.enable = true;

      environment.systemPackages = with pkgs; [
        virt-manager
        virt-viewer
        spice
        spice-gtk
        spice-protocol
        qemu
        win-virtio
        OVMF
      ];

      # Verzeichnisstruktur mit korrekten Berechtigungen
      systemd.tmpfiles.rules = [
        "d /var/lib/virt 0755 root root -"
        "d /var/lib/virt/testing 0775 root libvirt -"
        "d /var/lib/virt/testing/iso 0775 root libvirt -"  # ISO-Verzeichnis
        "d /var/lib/virt/testing/vars 0775 root libvirt -" # OVMF_VARS
        "d /var/lib/virt/testing/images 0775 root libvirt -" # VM-Images
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
    }

    {
      environment.systemPackages = [
        (cliTools.mkCommand {
          category = "vm";
          name = "test-nixos";
          description = "Create and manage NixOS test VMs";
          longDescription = ''
            Creates and manages NixOS test virtual machines with 
            configurable settings.
          '';
          examples = [
            "ncc-vm-test-nixos --memory 4096"
            "ncc-vm-test-nixos --variant gnome"
          ];
          script = ''
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
          '';
        })
      ];
    }
  ]);
}