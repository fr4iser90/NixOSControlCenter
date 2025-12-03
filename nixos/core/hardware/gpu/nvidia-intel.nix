{ config, lib, pkgs, systemConfig, ... }:

let
  nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.production;
  # requiresOpenFlag = lib.versionAtLeast nvidiaPackage.version "560.0.0"; # Removed

in
{
  # Add kernel module parameter correctly
  boot.extraModprobeConfig = ''
    options nvidia NVreg_OpenRmEnableUnsupportedGpus=1
  '';

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false; # Explicitly set to false for pre-Turing GPU
    package = nvidiaPackage;
#    powerManagement.enable = true;     # efi error 
    prime = {
      sync.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
  # // lib.mkIf requiresOpenFlag { # Removed conditional logic
  #   open = true;  # Wird nur hinzugefügt wenn Version >= 560
  # }; # Removed

  hardware.graphics = {
    enable = true;
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
