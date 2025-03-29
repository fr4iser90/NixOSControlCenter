# Configuration for dual AMD GPUs (discrete + integrated)
{ config, pkgs, systemConfig, ... }:

{
  services.xserver.videoDrivers = [ "amdgpu" ];

  environment.systemPackages = with pkgs; [
    libva-utils
    vaapiVdpau
    libvdpau-va-gl
    rocmPackages.rocm-smi # System Management Interface
  ];

  boot = {
    kernelModules = [ "amdgpu" ];
    initrd.kernelModules = [ "amdgpu" ];
  };
  
  # Session variables optimized for dual AMD GPUs
  environment.sessionVariables = {
    # Use discrete GPU for Wayland by default
    WLR_DRM_DEVICES = "/dev/dri/card0:/dev/dri/card1";
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_DRM_NO_ATOMIC = "1";
    AMD_VULKAN_ICD = "RADV";
    # Optimized for RDNA2 architecture (RX 6600M)
    RADV_PERFTEST = "aco,sam";
    MESA_SHADER_CACHE_DIR = "$HOME/.cache/mesa_shader_cache";
    # For video acceleration
    LIBVA_DRIVER_NAME = "radeonsi";
    # For power management
    AMDGPU_PSTATE = "auto";
  };
  
  hardware.enableRedistributableFirmware = true;
  hardware.amdgpu = {
    initrd.enable = true;
    opencl = true;
    loadInInitrd = true;
    amdvlk = true;
    # Enable DRI for better performance
    driSupport = true;
    driSupport32Bit = true;
  };
  
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-validation-layers
      mesa
      amdvlk
      rocm-opencl-icd
      rocm-opencl-runtime
    ];
  };

  # Power management for the discrete GPU
  powerManagement.enable = true;
  services.thermald.enable = true;
}
