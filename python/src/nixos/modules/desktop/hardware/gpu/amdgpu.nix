# /etc/nixos/modules/desktop/gpu/amdgpu.nix
{ config, pkgs, ... }:

{
  services.xserver.videoDrivers = [ "amdgpu" ];

  environment.systemPackages = with pkgs; [
    libva-utils
    vaapiVdpau
    libvdpau-va-gl
    vulkan-tools    # Für Vulkan-Diagnose
    glxinfo         # Für OpenGL-Diagnose
    radeontop       # Für AMD GPU-Monitoring
  ];

  hardware.graphics = {
    enable = true;  # Aktiviert OpenGL-Unterstützung
    extraPackages = with pkgs; [
      vulkan-loader       # Vulkan-Lader
      mesa                # Mesa-Treiber
    ];
 };
}
