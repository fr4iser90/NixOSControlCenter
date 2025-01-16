{ config, lib, pkgs, systemConfig, ... }:

let
  # Bootloader configurations
  bootloaders = {
    systemd-boot = ./bootloaders/systemd-boot.nix;
    grub = ./bootloaders/grub.nix;
    refind = ./bootloaders/refind.nix;
  };

  # Select bootloader configuration
  selectedLoader = bootloaders.${systemConfig.system.bootloader} or bootloaders.systemd-boot;

in {
  imports = [ selectedLoader ];

  # Common boot configuration
  boot = {
    initrd = {
      compressor = "zstd";
      compressorArgs = [ "-19" "-T0" ];
      systemd.enable = true;
      includeDefaultModules = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
  };

  assertions = [
    {
      assertion = builtins.hasAttr systemConfig.system.bootloader bootloaders;
      message = "Invalid bootloader selection: ${systemConfig.system.bootloader}";
    }
  ];
}