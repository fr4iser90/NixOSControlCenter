# Default VM configuration for testing
{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

with lib;

let
  # Use getModuleConfig to get the main VM config (Stage 1 pattern)
  cfg = getModuleConfig "vm";
  libVM = import ../lib { inherit lib pkgs; };

  mkTestVM = distro: {
    config,
    lib,
    pkgs,
    systemConfig,
    getModuleConfig,
    ...
  }: let
    # Access nested config via config.systemConfig (evaluated options with defaults)
    # Fallback to empty attrset if not set
    vmCfg = config.systemConfig.modules.infrastructure.vm.testing.${distro}.vm or {};
    vmName = "${distro}-test";
  in {
    # Fix options path to match systemConfig structure
    options.systemConfig.modules.infrastructure.vm.testing.${distro}.vm = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "${distro} VM for testing";
      };

      variant = mkOption {
        type = types.enum (attrNames libVM.distros.${distro}.variants);
        default = head (attrNames libVM.distros.${distro}.variants);
        description = "Distribution variant";
      };

      version = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Distribution version (null for default)";
      };

      memory = mkOption {
        type = types.int;
        default = libVM.distros.${distro}.defaultMemory or 4096;
        description = "RAM in MB";
      };

      cores = mkOption {
        type = types.int;
        default = libVM.distros.${distro}.defaultCores or 2;
        description = "CPU cores";
      };

      remote = {
        enable = mkEnableOption "Remote access";
        displayPort = mkOption {
          type = types.port;
          default = 5900 + libVM.distros.${distro}.portOffset or 0;
          description = "SPICE display port";
        };
      };

      image = {
        path = mkOption {
          type = types.path;
          default = "${cfg.stateDir}/testing/images/${vmName}.qcow2";
          description = "Path to VM image";
        };
        size = mkOption {
          type = types.int;
          default = libVM.distros.${distro}.defaultDiskSize or 40;
          description = "Image size in GB";
        };
      };
    };

    config = mkIf (vmCfg.enable or true) {
      # Statt command-center.commands, erstellen wir direkte Skripte
      environment.systemPackages = [
        (pkgs.writeScriptBin "vm-test-${distro}-run" ''
          set -e
          
          ${libVM.mkVmScript {
            name = vmName;
            inherit (vmCfg) memory cores image variant version;
            distro = distro;
            stateDir = cfg.stateDir;
          }}

          trap 'cleanup_and_exit' INT TERM
          
          cleanup_and_exit() {
            echo "Cleaning up..."
            sudo virsh destroy ${vmName} 2>/dev/null || true
            exit 0
          }

          prepare_ovmf
          create_disk
          iso_path=$(download_iso)
          start_vm "$iso_path"
        '')

        (pkgs.writeScriptBin "vm-test-${distro}-reset" ''
          set -e
          echo "Stopping VM if running..."
          sudo virsh destroy ${vmName} 2>/dev/null || true
          sudo virsh undefine ${vmName} --remove-all-storage 2>/dev/null || true
          sudo rm -f ${vmCfg.image.path}
          sudo rm -rf ${cfg.stateDir}/testing/iso/*
          sudo rm -rf ${cfg.stateDir}/testing/vars/*
          echo "Reset complete. You can now run 'ncc vm test-${distro}-run'"
        '')
      ];
    };
  };
in {
  imports = map (distro: mkTestVM distro) (attrNames libVM.distros);
}