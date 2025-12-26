{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  # System Checks Handler
  # Bietet prebuild/postbuild Checks als reine Component

  # Import check modules directly (not as submodule imports)
  hardwareUtils = import ../components/system-checks/prebuild/checks/hardware/utils.nix { inherit config lib; };
  gpuCheck = import ../components/system-checks/prebuild/checks/hardware/gpu.nix { inherit config lib pkgs systemConfig getModuleApi; };
  cpuCheck = import ../components/system-checks/prebuild/checks/hardware/cpu.nix { inherit config lib; };
  memoryCheck = import ../components/system-checks/prebuild/checks/hardware/memory.nix { inherit config lib pkgs systemConfig getModuleApi; };
  usersCheck = import ../components/system-checks/prebuild/checks/system/users.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; };

in {
  # System Checks Component Implementation

  # Required packages for checks
  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    lshw
  ] ++ (gpuCheck.environment.systemPackages or [])
    ++ (memoryCheck.environment.systemPackages or [])
    ++ (usersCheck.environment.systemPackages or []);
}
