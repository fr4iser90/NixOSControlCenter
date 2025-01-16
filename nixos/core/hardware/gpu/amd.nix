# /etc/nixos/modules/desktop/gpu/amdgpu.nix
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
  
  # Erweiterte Sitzungsvariablen
  environment.sessionVariables = {
    WLR_DRM_DEVICES = "/dev/dri/card1";
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_DRM_NO_ATOMIC = "1";
    AMD_VULKAN_ICD = "RADV";
    RADV_PERFTEST = "aco";
    MESA_SHADER_CACHE_DIR = "$HOME/.cache/mesa_shader_cache"; 
  };
  hardware.enableRedistributableFirmware = true;

  hardware.amdgpu.initrd.enable = true; #Whether to enable loading amdgpu kernelModule in stage 1. Can fix lower resolution in boot screen during initramfs phase
  hardware.graphics = {
    enable = true;  # Aktiviert OpenGL-Unterstützung
    extraPackages = with pkgs; [
      vulkan-loader       # Vulkan-Lader
      vulkan-validation-layers
      mesa                # Mesa-Treiber
      amdvlk
    ];
  };

  
}
