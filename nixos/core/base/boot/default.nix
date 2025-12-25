{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  # Single Source: Modulname nur einmal definieren
  moduleName = baseNameOf ./. ;  # ← boot aus core/base/boot/

  # Bootloader configurations
  bootloaders = {
    systemd-boot = ./handlers/systemd-boot.nix;
    grub = ./handlers/grub.nix;
    refind = ./handlers/refind.nix;
  };

  bootCfg = getModuleConfig moduleName;

in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Bootloader and boot configuration management";
    category = "base";
    subcategory = "boot";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;
  imports = [
    ./options.nix
    (import ./config.nix { inherit config lib pkgs getModuleConfig moduleName; })
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
