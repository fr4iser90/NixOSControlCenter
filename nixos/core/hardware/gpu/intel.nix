# /etc/nixos/modules/desktop/gpu/intel.nix
{ config, pkgs, systemConfig, ... }:

{
  services.xserver.videoDrivers = [ "intel" ]; # Use the Intel driver for integrated graphics
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vaapiIntel   # Intel VA-API driver for video acceleration.
      intel-media-sdk
      xorg.xf86videointel
    ];
  };


}
