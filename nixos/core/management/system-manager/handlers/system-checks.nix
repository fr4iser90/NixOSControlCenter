{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  # System Checks Handler
  # Imports ALL check modules and ensures their scripts are in systemPackages
  
  # Import check modules with ALL required parameters
  hardwareUtils = import ../components/system-checks/prebuild/checks/hardware/utils.nix { inherit config lib; };
  cpuCheck = import ../components/system-checks/prebuild/checks/hardware/cpu.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };
  gpuCheck = import ../components/system-checks/prebuild/checks/hardware/gpu.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };
  memoryCheck = import ../components/system-checks/prebuild/checks/hardware/memory.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };
  platformCheck = import ../components/system-checks/prebuild/checks/hardware/platform.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };
  usersCheck = import ../components/system-checks/prebuild/checks/system/users.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };
  flakeExtras = import ../components/system-checks/prebuild/checks/system/flake-extras.nix { inherit pkgs getModuleApi; };
  remoteInstallGateMod = import ../components/system-checks/scripts/remote-install-gate.nix { inherit pkgs getModuleApi; };

in {
  # Merge all check module configs to ensure ALL scripts are available
  imports = [
    platformCheck
    cpuCheck
    gpuCheck  
    memoryCheck
    usersCheck
    flakeExtras.nixosModule
  ];

  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    lshw
    remoteInstallGateMod.remoteInstallGate
  ];
}
