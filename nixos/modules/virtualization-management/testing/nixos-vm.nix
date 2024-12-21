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
      cli-management.categories.vm = "Virtual Machine Management";
    }

    {
      # QEMU/KVM und SPICE Konfiguration
      virtualisation = {
        libvirtd = {
          enable = true;
          qemu = {
            swtpm.enable = true;
            ovmf.enable = true;
          };
        };
        spiceUSBRedirection.enable = true;
      };

      # Benötigte Pakete
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

      # Firewall-Regeln für SPICE
      networking.firewall = mkIf cfg.remote.enable {
        allowedTCPPorts = [ cfg.remote.displayPort ];
      };

      # Benutzerrechte
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
      environment.systemPackages = let
        cliTools = config.cli-management.tools;
      in [
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

        (cliTools.mkCommand {
          category = "vm";
          name = "test-nixos-reset";
          description = "Reset NixOS test VM";
          longDescription = ''
            Removes all files associated with the NixOS test VM and prepares for fresh setup.
          '';
          script = ''
            set -e
            
            echo "Stopping VM if running..."
            sudo virsh destroy nixos-test 2>/dev/null || true
            
            echo "Removing VM from libvirt..."
            sudo virsh undefine nixos-test --remove-all-storage 2>/dev/null || true
            
            echo "Cleaning up files..."
            sudo rm -f ${cfg.image.path}
            sudo rm -rf /var/lib/virt/testing/iso/*
            sudo rm -rf /var/lib/virt/testing/vars/*
            
            echo "Reset complete. You can now run ncc-vm-test-nixos to create a fresh VM."
          '';
        })
      ];
    }
  ]);
}