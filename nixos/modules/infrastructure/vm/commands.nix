{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, moduleName, ... }:

with lib;

let
  # Get config using getModuleConfig (includes template-config.nix defaults)
  cfg = getModuleConfig moduleName;
  # Get CLI registry API
  cliRegistry = getModuleApi "cli-registry";
  # Get UI utilities
  ui = getModuleApi "cli-formatter";
  # Get VM library
  libVM = import ./lib { inherit lib pkgs; };
  
  # Get list of available distros
  availableDistros = attrNames libVM.distros;
  
  # VM status command
  vmStatus = pkgs.writeShellScriptBin "ncc-vm-status" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "${ui.badges.info "🖥️  VM Manager Status"}"
    
    # Check if libvirtd is running
    if systemctl is-active --quiet libvirtd.service; then
      echo "${ui.tables.keyValue "Libvirt Daemon" "Running"}"
    else
      echo "${ui.badges.warning "Libvirt daemon not running"}"
      echo "${ui.messages.info "Start with: sudo systemctl start libvirtd"}"
      exit 1
    fi
    
    # List running VMs
    echo ""
    echo "${ui.badges.info "Running VMs:"}"
    if virsh list --state-running 2>/dev/null | grep -q "running"; then
      virsh list --state-running
    else
      echo "${ui.messages.info "No VMs currently running"}"
    fi
    
    # List all VMs
    echo ""
    echo "${ui.badges.info "All VMs:"}"
    if virsh list --all 2>/dev/null | grep -q "Id"; then
      virsh list --all
    else
      echo "${ui.messages.info "No VMs defined"}"
    fi
  '';
  
  # VM list command
  vmList = pkgs.writeShellScriptBin "ncc-vm-list" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "${ui.badges.info "📋 Available VM Test Distros"}"
    echo ""
    
    ${lib.concatMapStringsSep "\n" (distro: ''
      echo "${ui.tables.keyValue "${distro}" "ncc vm test-${distro}-run"}"
    '') availableDistros}
    
    echo ""
    echo "${ui.messages.info "Use 'ncc vm test-<distro>-run' to start a test VM"}"
    echo "${ui.messages.info "Use 'ncc vm test-<distro>-reset' to reset a test VM"}"
  '';
  
  # Create commands for each distro
  distroCommands = lib.concatMap (distro: let
    vmName = "${distro}-test";
    # Get config for this distro (with fallbacks)
    vmCfg = config.systemConfig.modules.infrastructure.vm.testing.${distro}.vm or {};
    stateDir = cfg.stateDir or "/var/lib/virt";
    
    # Run command
    runScript = pkgs.writeShellScriptBin "ncc-vm-test-${distro}-run" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      
      echo "${ui.badges.info "🚀 Starting ${distro} test VM"}"
      
      # Check if VM already exists and is running
      if virsh dominfo ${vmName} >/dev/null 2>&1; then
        if virsh dominfo ${vmName} | grep -q "State:.*running"; then
          echo "${ui.badges.warning "VM ${vmName} is already running"}"
          echo "${ui.messages.info "Use 'virsh console ${vmName}' to connect"}"
          exit 0
        fi
      fi
      
      # Use the system package script if available
      if command -v vm-test-${distro}-run >/dev/null 2>&1; then
        exec vm-test-${distro}-run
      else
        echo "${ui.badges.error "VM test script not found"}"
        echo "${ui.messages.info "Make sure the VM module is enabled and rebuilt"}"
        exit 1
      fi
    '';
    
    # Reset command
    resetScript = pkgs.writeShellScriptBin "ncc-vm-test-${distro}-reset" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      
      echo "${ui.badges.warning "⚠️  Resetting ${distro} test VM"}"
      
      # Use the system package script if available
      if command -v vm-test-${distro}-reset >/dev/null 2>&1; then
        exec vm-test-${distro}-reset
      else
        # Fallback: manual reset
        echo "${ui.messages.info "Stopping VM if running..."}"
        sudo virsh destroy ${vmName} 2>/dev/null || true
        sudo virsh undefine ${vmName} --remove-all-storage 2>/dev/null || true
        sudo rm -f ${stateDir}/testing/images/${vmName}.qcow2
        sudo rm -rf ${stateDir}/testing/iso/*
        sudo rm -rf ${stateDir}/testing/vars/*
        echo "${ui.badges.success "Reset complete"}"
      fi
    '';
  in [
    {
      name = "test-${distro}-run";
      domain = "vm";
      parent = "vm";
      description = "Start ${distro} test VM";
      category = "infrastructure";
      script = "${runScript}/bin/ncc-vm-test-${distro}-run";
      arguments = [];
      dependencies = [ "qemu" "libvirt" ];
      shortHelp = "test-${distro}-run - Start ${distro} test VM";
      longHelp = ''
        Start a test VM with ${distro}.
        
        This will:
        - Download the ISO if needed
        - Create a disk image if needed
        - Start the VM with QEMU/KVM
        
        Requirements:
        - libvirtd must be running
        - KVM support enabled
      '';
    }
    {
      name = "test-${distro}-reset";
      domain = "vm";
      parent = "vm";
      description = "Reset ${distro} test VM (delete disk and config)";
      category = "infrastructure";
      script = "${resetScript}/bin/ncc-vm-test-${distro}-reset";
      arguments = [];
      dependencies = [ "libvirt" ];
      shortHelp = "test-${distro}-reset - Reset ${distro} test VM";
      longHelp = ''
        Reset the ${distro} test VM by:
        - Stopping the VM if running
        - Removing the VM definition
        - Deleting the disk image
        - Cleaning up ISO and VARS files
        
        WARNING: This will delete all data on the VM!
      '';
      dangerous = true;
    }
  ]) availableDistros;
  
  # Combine all commands into a single list - HIERARCHICAL STRUCTURE
  allCommands = [
    # VM Domain Manager (TUI launcher)
    {
      name = "vm";
      domain = "vm";
      type = "manager";
      description = "VM Manager - Manage virtual machines";
      category = "infrastructure";
      script = "${vmStatus}/bin/ncc-vm-status";
      shortHelp = "vm - VM Manager (TUI)";
      longHelp = ''
        VM Manager provides commands to manage virtual machines.
        
        Usage:
          ncc vm              - Show VM status (TUI)
          ncc vm status       - Show VM manager status
          ncc vm list         - List available test distros
          ncc vm test-<distro>-run   - Start test VM
          ncc vm test-<distro>-reset - Reset test VM
        
        Examples:
          ncc vm status
          ncc vm list
          ncc vm test-nixos-run
          ncc vm test-ubuntu-reset
      '';
    }
    # Subcommand: status
    {
      name = "status";
      domain = "vm";
      parent = "vm";
      description = "Show VM manager status and running VMs";
      category = "infrastructure";
      script = "${vmStatus}/bin/ncc-vm-status";
      arguments = [];
      dependencies = [ "libvirt" ];
      shortHelp = "status - Show VM manager status";
      longHelp = ''
        Display current VM manager status including:
        - Libvirt daemon status
        - Running VMs
        - All defined VMs
      '';
    }
    # Subcommand: list
    {
      name = "list";
      domain = "vm";
      parent = "vm";
      description = "List available test VM distros";
      category = "infrastructure";
      script = "${vmList}/bin/ncc-vm-list";
      arguments = [];
      shortHelp = "list - List available test distros";
      longHelp = ''
        Display all available distros for test VMs.
        
        Use 'ncc vm test-<distro>-run' to start a VM.
      '';
    }
  ] ++ distroCommands;
  
  # Register all commands via CLI Registry API
  registrationResult = cliRegistry.registerCommandsFor "vm" allCommands;
  
in
{
  config = lib.mkMerge [
    registrationResult
  ];
}
