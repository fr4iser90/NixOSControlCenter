{ config, lib, pkgs, systemConfig, ... }:

let
  nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.stable;
  requiresOpenFlag = lib.versionAtLeast nvidiaPackage.version "560.0.0";
in
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    package = nvidiaPackage;
  } // lib.mkIf requiresOpenFlag {
    open = true;  # Wird nur hinzugefügt wenn Version >= 560
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Required for x86_64 systems with NVIDIA
    extraPackages = with pkgs; [
      nvidiaPackage
    ];
  };


  # NVIDIA driver options (uncomment to use a different version)
  # hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;       # Stable driver
  # hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.beta;         # Beta driver
  # hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;   # Production driver (default, installs 550)
  # hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.vulkan_beta;  # Vulkan beta driver
  # hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy_470;   # Legacy driver (470 series)
  # hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy_390;   # Legacy driver (390 series)
  # hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.legacy_340;   # Legacy driver (340 series)
}
