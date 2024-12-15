# /etc/nixos/modules/desktop/gpu/amdgpu.nix
{ config, pkgs, ... }:

{
  services.xserver.videoDrivers = [ "amdgpu" ];

  environment.systemPackages = with pkgs; [
    libva-utils
    vaapiVdpau
    libvdpau-va-gl
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
  };
  
  # Erweiterte Sitzungsvariablen
  environment.sessionVariables = {
    WLR_DRM_DEVICES = "/dev/dri/card1"; # Angepasst an deine Karte (card1)
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_DRM_NO_ATOMIC = "1";
  };
  hardware.enableRedistributableFirmware = true;

  hardware.amdgpu.initrd.enable = true; #Whether to enable loading amdgpu kernelModule in stage 1. Can fix lower resolution in boot screen during initramfs phase
  hardware.graphics = {
    enable = true;  # Aktiviert OpenGL-Unterstützung
    extraPackages = with pkgs; [
      vulkan-loader       # Vulkan-Lader
      mesa                # Mesa-Treiber
      amdvlk
    ];
  };

  
}
