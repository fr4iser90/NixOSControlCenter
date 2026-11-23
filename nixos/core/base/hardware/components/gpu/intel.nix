# /etc/nixos/modules/desktop/gpu/intel.nix
{ config, pkgs, systemConfig, ... }:

{
  services.xserver.videoDrivers = [ "modesetting" ]; # Use the Intel driver for integrated graphics
  hardware.graphics = {
    enable = true;
    # nixpkgs 26.05+: vaapiIntel → intel-vaapi-driver (alias throws).
    # Tiger Lake+ / Broadwell+: also ship intel-media-driver (iHD).
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      intel-media-sdk
    ];
  };


}
