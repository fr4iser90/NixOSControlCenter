{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  # System Checks Handler
  # Imports ALL check modules and ensures their scripts are in systemPackages
  
  # Import check modules with ALL required parameters
  hardwareUtils = import ../components/system-checks/prebuild/checks/hardware/utils.nix { inherit config lib; };
  cpuCheck = import ../components/system-checks/prebuild/checks/hardware/cpu.nix { inherit config lib pkgs systemConfig getModuleApi; };
  gpuCheck = import ../components/system-checks/prebuild/checks/hardware/gpu.nix { inherit config lib pkgs systemConfig getModuleApi; };
  memoryCheck = import ../components/system-checks/prebuild/checks/hardware/memory.nix { inherit config lib pkgs systemConfig getModuleApi; };
  usersCheck = import ../components/system-checks/prebuild/checks/system/users.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };

in {
  # Merge all check module configs to ensure ALL scripts are available
  imports = [
    cpuCheck
    gpuCheck  
    memoryCheck
    usersCheck
  ];

  # Base system packages for hardware detection
  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    lshw
  ];
}
