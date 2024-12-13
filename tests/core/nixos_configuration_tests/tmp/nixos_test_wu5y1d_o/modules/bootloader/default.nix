{ config, lib, pkgs, ... }:

let
  env = import ../../env.nix;
  
  # Import core libraries
  entryManagement = import ./lib/entry-management {
    inherit config lib pkgs;
  };
  
  # Bootloader configurations
  bootloaders = {
    systemd-boot = {
      module = ./bootloaders/systemd-boot.nix;
      provider = entryManagement.providers.systemd-boot;
    };
    grub = {
      module = ./bootloaders/grub.nix;
      provider = entryManagement.providers.grub;
    };
    refind = {
      module = ./bootloaders/refind.nix;
      provider = entryManagement.providers.refind;
    };
  };

  # Select bootloader configuration
  selectedLoader = bootloaders.${env.bootloader} or bootloaders.systemd-boot;
  bootloaderConfig = import selectedLoader.module {
    inherit config lib pkgs env;
    entryManager = selectedLoader.provider;
  };

in {
  imports = [ bootloaderConfig ];

  # Common boot configuration
  boot = {
    initrd = {
      compressor = "zstd";
      compressorArgs = [ "-19" "-T0" ];
      systemd.enable = true;
      includeDefaultModules = true;
    };
  };

  # Make bootloader-specific utilities available
  environment.systemPackages = with selectedLoader.provider.scripts; [
    listEntries
    renameEntry
    resetEntry
  ];

  # Add common activation scripts
  system.activationScripts = {
    bootEntryInit = entryManagement.activation.initializeJson;
    bootEntrySync = lib.mkIf (env.bootloader == "systemd-boot") 
      entryManagement.activation.syncEntries;
  };

  assertions = [
    {
      assertion = builtins.hasAttr env.bootloader bootloaders;
      message = "Invalid bootloader selection: ${env.bootloader}";
    }
  ];
}