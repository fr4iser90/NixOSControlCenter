{ config, lib, pkgs, systemConfig, ... }:

let
  # Bootloader configurations
  bootloaders = {
    systemd-boot = ./bootloaders/systemd-boot.nix;
    grub = ./bootloaders/grub.nix;
    refind = ./bootloaders/refind.nix;
  };

in {
  imports = [
    ./options.nix
    ./config.nix
    (bootloaders.${systemConfig.bootloader or "systemd-boot"})
  ];

  # Common boot configuration
  boot = {
    initrd = {
      compressor = "zstd";
      compressorArgs = [ "-19" "-T0" ];
      includeDefaultModules = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
  };

  assertions = [
    {
      assertion = builtins.hasAttr systemConfig.bootloader bootloaders;
      message = "Invalid bootloader selection: ${systemConfig.bootloader}";
    }
  ];
}
