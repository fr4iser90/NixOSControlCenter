{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Bootloader configurations
  bootloaders = {
    systemd-boot = ./bootloaders/systemd-boot.nix;
    grub = ./bootloaders/grub.nix;
    refind = ./bootloaders/refind.nix;
  };

  bootCfg = getModuleConfig "boot";

in {
  _module.metadata = {
    role = "core";
    name = "boot";
    description = "Bootloader and boot configuration management";
    category = "base";
    subcategory = "boot";
    version = "1.0.0";
  };
  imports = [
    ./options.nix
    ./config.nix
    (bootloaders.${bootCfg.bootloader or "systemd-boot"})
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
      assertion = builtins.hasAttr (bootCfg.bootloader or "systemd-boot") bootloaders;
      message = "Invalid bootloader selection: ${bootCfg.bootloader or "systemd-boot"}";
    }
  ];
}
