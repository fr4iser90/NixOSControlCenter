# /etc/nixos/modules/desktop/gpu/intel.nix
{ config, pkgs, systemConfig, ... }:

{
  services.xserver.videoDrivers = [ "modesetting" ]; # Use the Intel driver for integrated graphics
  hardware.graphics = {
    enable = true;
    # nixpkgs 26.05+: vaapiIntel → intel-vaapi-driver (alias throws).
    # Do not pull intel-media-sdk — marked insecure/EOL (CVE-2023-*).
    # Tiger Lake+: intel-media-driver (iHD) + vpl-gpu-rt (Media SDK successor).
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      vpl-gpu-rt
    ];
  };


}
